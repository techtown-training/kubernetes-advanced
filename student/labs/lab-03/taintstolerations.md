# Working With Taints and Tolerations Along With Node Selectors

Check if one of the nodes has any taint configured by looking at the "Taint" property:

```
$ kubectl describe node ip-10-192-20-79.ec2.internal
Name:               ip-10-192-20-79.ec2.internal
Roles:              <none>
Labels:             beta.kubernetes.io/arch=amd64
                    beta.kubernetes.io/instance-type=t3.medium
                    beta.kubernetes.io/os=linux
                    failure-domain.beta.kubernetes.io/region=us-east-1
                    failure-domain.beta.kubernetes.io/zone=us-east-1a
                    kubernetes.io/arch=amd64
                    kubernetes.io/hostname=ip-10-192-20-79.ec2.internal
                    kubernetes.io/os=linux
Annotations:        node.alpha.kubernetes.io/ttl: 0
                    volumes.kubernetes.io/controller-managed-attach-detach: true
CreationTimestamp:  Fri, 17 Apr 2020 18:26:18 +0000
Taints:             <none>
```

Create a taint in all the nodes of the cluster using the following command:

```
kubectl taint node ip-10-192-20-79.ec2.internal app=sensitive:NoSchedule
kubectl taint node ip-10-192-21-228.ec2.internal app=sensitive:NoSchedule
kubectl taint node ip-10-192-22-186.ec2.internal app=sensitive:NoSchedule
```

Create a new pod using the following YAML manifest:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp-sensitive
spec:
  containers:
  - image: nginx
    name: sensitive
EOF
$ kubectl describe pod webapp-sensitive
```

Is the pod running? What is the latest event saying?

Modify the existing pod to add a toleration:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp-sensitive
spec:
  containers:
  - image: nginx
    name: sensitive
  tolerations:
  - key: app
    value: sensitive
    effect: NoSchedule
    operator: Equal
EOF
$ kubectl describe pod webapp-sensitive
$ kubectl get pods -o wide
```

Is the pod running now?

Check what labels you have by default in a worker node:

```
$ kubectl describe node ip-10-192-20-79.ec2.internal
Name:               ip-10-192-20-79.ec2.internal
Roles:              <none>
Labels:             beta.kubernetes.io/arch=amd64
                    beta.kubernetes.io/instance-type=t3.medium
                    beta.kubernetes.io/os=linux
                    failure-domain.beta.kubernetes.io/region=us-east-1
                    failure-domain.beta.kubernetes.io/zone=us-east-1a
                    kubernetes.io/arch=amd64
                    kubernetes.io/hostname=ip-10-192-20-79.ec2.internal
                    kubernetes.io/os=linux
```

Let's enforce the scheduling of a pod by adding a label to a node:

```
$ kubectl label node ip-10-192-20-79.ec2.internal color=blue
```

Create a new deployment with six replicas:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: blue
  name: blue
spec:
  replicas: 6
  selector:
    matchLabels:
      run: blue
  template:
    metadata:
      labels:
        run: blue
    spec:
      containers:
      - image: nginx
        name: blue
      tolerations:
      - key: app
        value: sensitive
        effect: NoSchedule
        operator: Equal
EOF
$ kubectl get pods -o wide
```

Where are the pods running now? In all nodes, right? Let's add a node affinity to enforce scheduling:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: blue
  name: blue
spec:
  replicas: 6
  selector:
    matchLabels:
      run: blue
  template:
    metadata:
      labels:
        run: blue
    spec:
      containers:
      - image: nginx
        name: blue
      tolerations:
      - key: app
        value: sensitive
        effect: NoSchedule
        operator: Equal
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: color
                operator: In
                values:
                - blue
EOF
$ kubectl get pods -o wide
```

Now all pods should be running in the same worker node.

Clean up what you did, otherwise the upcoming labs won't work correctly.

Remove taints and labels in nodes with the following commands:

```
kubectl taint node ip-10-192-20-79.ec2.internal app:NoSchedule-
kubectl taint node ip-10-192-21-228.ec2.internal app:NoSchedule-
kubectl taint node ip-10-192-22-186.ec2.internal app:NoSchedule-
kubectl label node ip-10-192-20-79.ec2.internal color-
```

Remove pods and deployments:

```
kubectl delete deployment blue
kubectl delete pod webapp-sensitive
```
