# Working With Networking Policies

Deploy the Calico DaemonSet; otherwise the networking policies won't work:

```
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.5/config/v1.5/calico.yaml
kubectl get daemonset calico-node --namespace kube-system
```

Deploy the following app:

```
---
apiVersion: v1
kind: Namespace
metadata:
  name: "netpol"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "service-a"
  namespace: "netpol"
spec:
  selector:
    matchLabels:
      app: "service-a"
  replicas: 1
  template:
    metadata:
      labels:
        app: "service-a"
        layer: "frontend"
    spec:
      containers:
      - image: christianhxc/nginx
        imagePullPolicy: Always
        name: "service-a"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: "service-a"
  namespace: "netpol"
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: LoadBalancer
  selector:
    app: "service-a"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "service-b"
  namespace: "netpol"
spec:
  selector:
    matchLabels:
      app: "service-b"
  replicas: 1
  template:
    metadata:
      labels:
        app: "service-b"
    spec:
      containers:
      - image: christianhxc/nginx
        imagePullPolicy: Always
        name: "service-b"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: "service-b"
  namespace: "netpol"
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: LoadBalancer
  selector:
    app: "service-b"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "service-c"
  namespace: "netpol"
spec:
  selector:
    matchLabels:
      app: "service-c"
  replicas: 1
  template:
    metadata:
      labels:
        app: "service-c"
    spec:
      containers:
      - image: christianhxc/nginx
        imagePullPolicy: Always
        name: "service-c"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: "service-c"
  namespace: "netpol"
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: LoadBalancer
  selector:
    app: "service-c"
---
```

You should be able to `curl` to all pods in the `netpol` namespace. Use the pod names corresponding to your cluster:

```
$ kubectl exec -n netpol service-a-6455c6db6-v8rdf -- wget -qO- --timeout=2 http://service-c.netpol.svc.cluster.local
$ kubectl run --generator=run-pod/v1 test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://service-b.netpol.svc.cluster.local
```

Let's use the following YAML manifest for a deny networking policy that applies to all pods:

```
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny
  namespace: "netpol"
spec:
  podSelector: {}
```

Create the networking policy in the `netpol` namespace:

```
kubectl apply -f default-deny.yaml
kubectl describe networkpolicy default-deny -n netpol
```

Verify that you can't connect to the service anymore from the default namespace (it won't work from the `netpol` namespace either):

```
$ kubectl run --generator=run-pod/v1 test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=1 http://service-b.netpol.svc.cluster.local
```

Create the policy to allow the communication to `service-a` because is the front-facing one:

```
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: netpol
  name: frontend-policy
spec:
  podSelector:
    matchLabels:
      layer: frontend
  ingress:
    - ports:
        - port: 80
```

Confirm that you can connect to `service-a`, or you can even give it a try with the browser using the ELB DNS name in AWS:

```
$ kubectl run --generator=run-pod/v1 test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=1 http://service-a.netpol.svc.cluster.local
/ # wget -qO- --timeout=1 http://service-b.netpol.svc.cluster.local
/ # wget -qO- --timeout=1 http://service-c.netpol.svc.cluster.local
$ kubectl get svc service-a -n netpol
```

Create the policy to allow the communication flow `service a -> service b -> service c`:

```
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: netpol
  name: a-to-b-policy
spec:
  podSelector:
    matchLabels:
      app: service-b
  ingress:
    - ports:
        - port: 80
      from:
        - podSelector:
            matchLabels:
              app: service-a
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: netpol
  name: b-to-c-policy
spec:
  podSelector:
    matchLabels:
      app: service-c
  ingress:
    - ports:
        - port: 80
      from:
        - podSelector:
            matchLabels:
              app: service-b
---
```

Get the proper names of the pods, and make some communication tests to confirm that everything is working:

```
$ kubectl exec -n netpol service-a-678766fc47-krh82 -- wget -qO- --timeout=1 http://service-b.netpol.svc.cluster.local
$ kubectl exec -n netpol service-a-678766fc47-krh82 -- wget -qO- --timeout=1 http://service-c.netpol.svc.cluster.local
$ kubectl exec -n netpol service-b-56f4b59db6-8wl8m -- wget -qO- --timeout=1 http://service-c.netpol.svc.cluster.local
$ kubectl run --generator=run-pod/v1 test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=1 http://service-a.netpol.svc.cluster.local
/ # wget -qO- --timeout=1 http://service-b.netpol.svc.cluster.local
/ # wget -qO- --timeout=1 http://service-c.netpol.svc.cluster.local
```

**Can service-c communicate with service-a? If yes, why and how could you fix it?**
