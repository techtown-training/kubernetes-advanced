# Creating Fault-Tolerant Applications

## ConfigMaps

Create a ConfigMap to store the background color of the application using the following command:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: website
data:
  bgcolor: white
EOF
$ kubectl describe configmap website
```

Take the background color configuration value from the ConfigMap in a pod, and run the following command:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp-color
spec:
  containers:
    - name: webapp
      image: christianhxc/nginx:1.0-color
      imagePullPolicy: Always
      env:
        - name: BGCOLOR
          valueFrom:
            configMapKeyRef:
              name: website
              key: bgcolor
EOF
$ kubectl get pod webapp-color
$ kubectl exec -it webapp-color -- cat /usr/html/index.html
```

Change the background in the ConfigMap, and deploy the pod again.

```
$ kubectl edit configmap website
$ kubectl delete pod webapp-color
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp-color
spec:
  containers:
    - name: webapp
      image: christianhxc/nginx:1.0-color
      imagePullPolicy: Always
      env:
        - name: BGCOLOR
          valueFrom:
            configMapKeyRef:
              name: website
              key: bgcolor
EOF
$ kubectl get pod webapp-color
$ kubectl exec -it webapp-color -- cat /usr/html/index.html
```

## Liveness and Readiness Probes

Create the following application in Kubernetes:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: weather
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
  namespace: weather
spec:  
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis
---
kind: Service
apiVersion: v1
metadata:
  name:  redis
  namespace: weather
spec:
  type:  ClusterIP
  ports:
  - 
    port:  6379
    targetPort:  6379
  selector:
    app: redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mssql-deployment
  namespace: weather
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: mssql
  template:
    metadata:
      labels:
        app: mssql
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: sqlserver
        image: microsoft/mssql-server-linux
        env:
          - name : ACCEPT_EULA
            value: "Y"
          - name : SA_PASSWORD
            value: "SuperPass2018"      
          - name: MSSQL_PID
            value: "Developer" 
---
apiVersion: v1
kind: Service
metadata:
  name: mssql
  namespace: weather
spec:
  selector:
    app: mssql
  ports:
    - protocol: TCP
      port: 1433
      targetPort: 1433
  type:  ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather
  labels:
    app: weather
  namespace: weather
spec:
  replicas: 3
  selector:
    matchLabels:
      app: weather
  template:
    metadata:
      labels:
        app: weather
    spec:
      containers:
      - name: weather
        image: christianhxc/weather:1.1
        imagePullPolicy: Always
        ports:
        - containerPort: 80        
        env:
        - name: MSSQL_SA_PASSWORD
          value: "SuperPass2018" 
---
apiVersion: v1
kind: Service
metadata:
  name: weather
  namespace: weather
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: weather
EOF
```

Wait some time until the app is ready to receive requests. It takes time to create the ELB and download the Microsoft SQL image. Make sure you can access the application using the public endpoint from the service, which is the ALB DNS endpoint.

Now, open the app in the web browser. Use the following link but with your own DNS endpoint:

```
http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/weatherforecast
```

Let's start watching the status of the running pods by using the following command:

```
$ watch kubectl get pods -n weather
```

The application has a path to inject chaos. Open it, and then open the live path as well to see that the API is unhealthy:

```
http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/chaos
http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/live
```

Notice that nothing is happening in the pods running, it doesn't restart, and the application is still (or sometimes) returning "Unhealthy."

Let's run a test in a new terminal tab so that you can see that the application is not working smoothly:

```
$ kubectl run --generator=run-pod/v1 -n weather test-$RANDOM --rm -i -t --image=alpine -- sh
/ # cat <<EOF > test.sh
#!/bin/sh 
while true
do wget -qO- --timeout=2 http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/live
sleep .1
done
EOF
/ # sh ./test.sh
```

Don't close this tab, as we'll continue using it to see the application behavior.

Let's make the application more resilient by adding a liveness probe. Deploy the web app again using the following command:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather
  labels:
    app: weather
  namespace: weather
spec:
  replicas: 3
  selector:
    matchLabels:
      app: weather
  template:
    metadata:
      labels:
        app: weather
    spec:
      containers:
      - name: weather
        image: christianhxc/weather:1.1
        imagePullPolicy: Always
        ports:
        - containerPort: 80        
        env:
        - name: MSSQL_SA_PASSWORD
          value: "SuperPass2018"
        livenessProbe:
          httpGet:
            path: /live
            port: 80
            scheme: HTTP
          initialDelaySeconds: 3
          periodSeconds: 5
EOF
```

Call the chaos endpoint. You can even try incognito mode if you want:

```
http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/chaos
```

Notice what happens with the pods that you're watching. Keep the application tests running as well.

Are they restarting? It will take some time, and sometimes the load balancer will hit the same pod, too, so try again.

Let's make the application more resilient by adding a readiness probe. This could be more intensive than the liveness probe:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather
  labels:
    app: weather
  namespace: weather
spec:
  replicas: 3
  selector:
    matchLabels:
      app: weather
  template:
    metadata:
      labels:
        app: weather
    spec:
      containers:
      - name: weather
        image: christianhxc/weather:1.1
        imagePullPolicy: Always
        ports:
        - containerPort: 80        
        env:
        - name: MSSQL_SA_PASSWORD
          value: "SuperPass2018"
        livenessProbe:
          httpGet:
            path: /live
            port: 80
            scheme: HTTP
          initialDelaySeconds: 3
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
            scheme: HTTP
          initialDelaySeconds: 1
          periodSeconds: 3
EOF
```

Let's shut down the MS SQL pods. The "ready" endpoint checks that the database is up:

```
kubectl scale deployment mssql-deployment --replicas=0 -n weather
```

Notice that the pods are alive but one of their dependencies isn't; they're still there, but the READY column says 0/1.

In a real scenario, maybe one or some of the pods will not be ready, but it's unlikely that all the pods will not be ready. It's also unlikely that pods will get out of traffic. But because we are using the same images and dependencies on this deployment, all pods are expelled from service.

Bring the database pod up again. Notice that the application will continue running:

```
kubectl scale deployment mssql-deployment --replicas=1 -n weather
```

## Taints/Tolerations and Node Selectors

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

Now, all pods should be running in the same worker node.

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

## Scaling Policies

Cluster Autoscaler is already installed and configured in the clusters, we'll configure the horizontal pod autoscaler (HPA).

First, let's deploy the `Metrics Server` in Kubernetes:

```
$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
$ kubectl get deployment metrics-server -n kube-system
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           49s
```

Let's create a simple web app with the following command. Notice you're specifying the `requests` and `limits` for pods:

```
kubectl run httpd --image=httpd --requests=cpu=100m --limits=cpu=200m --expose --port=80
```

Configure HPA for the web app you created:

```
kubectl autoscale deployment httpd --cpu-percent=50 --min=1 --max=10
```

When the average CPU load is below 50 percent, the autoscaler tries to reduce the number of pods in the deployment (to a minimum of one pod). When the load is greater than 50 percent, the autoscaler tries to increase the number of pods in the deployment (up to a maximum of 10).

Get the details for the autoscaler:

```
$ kubectl describe hpa/httpd
```

The current CPU load is only one percent, but the pod count is already at its lowest boundary (one), so it cannot scale in.

Let's send some load test to the web app:

```
$ kubectl run apache-bench -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://httpd.default.svc.cluster.local/
```

In a new tab, keep an eye on the autoscaler object to see how it scales:

```
$ watch kubectl get horizontalpodautoscaler.autoscaling/httpd
```

Clean up the deployment:

```
$ kubectl delete deployment.apps/httpd service/httpd horizontalpodautoscaler.autoscaling/httpd
```

## Cluster Autoscaler

If times allows it, you can give scaling up the cluster autoscaler a try with the following commands:

```
$ kubectl get nodes
$ kubectl create deployment autoscaler-demo --image=nginx
$ kubectl scale deployment autoscaler-demo --replicas=50
$ watch kubectl get deployment autoscaler-demo
$ kubectl get nodes
```

To scale down again:

```
$ kubectl delete deployment autoscaler-demo
$ kubectl get nodes
```
