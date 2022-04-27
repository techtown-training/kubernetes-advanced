# Configuring and Testing HPA in Kubernetes

Cluster autoscaler is already installed and configured in the clusters, we'll configure the horizontal pod autoscaler (HPA).

First, let's deploy the `Metrics Server` in Kubernetes:

```
$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
$ kubectl get deployment metrics-server -n kube-system
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           49s
```

Let's create a simple web app with the following command. Notice you're specifying the `requests` and `limits` for pods:

_web-app.yaml_
```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpd
spec:
  replicas: 3
  selector:
    matchLabels:
      app: httpd
  template:
    metadata:
      labels:
        app: httpd
    spec:
      containers:
      - name: httpd
        image: httpd:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
          limits:
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: httpd
spec:
  selector:
    app: httpd
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
...
```

```
kubectl apply -f web-app.yaml
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

Let's send some load tests to the web app:

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
