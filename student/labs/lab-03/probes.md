# Working With Liveness and Readiness Probes

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

Let's start watching the status of the running pods. Use the following command:

```
$ watch kubectl get pods -n weather
```

The application has a path to inject chaos. Open it, and then open the live path as well to see that the API is unhealthy:

```
http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/chaos
http://a0689dc978ad24c9daf90c2deb3a6925-1277370993.us-east-1.elb.amazonaws.com/live
```

Notice that nothing is happening in the pods running, it doesn't restart, and the application still (or sometimes) returns "Unhealthy".

Let's leave running a test in a new terminal tab so that you can see that it's not working smoothly:

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

Let's make it more resilient by adding the liveness probe. Deploy the web app again using the following command:

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

Notice that the pods are alive but that one of their dependencies isn't. They're still there, but the READY column says 0/1.

In a real scenario, maybe one or some of the pods will not be ready, but it's unlikely that all the pods will not be ready. It's also unlikely that pods will get out of traffic. But because we are using the same images and dependencies on this deployment, all pods are expelled from service.

Bring the database pod up again, and notice that the application will continue running:

```
kubectl scale deployment mssql-deployment --replicas=1 -n weather
```
