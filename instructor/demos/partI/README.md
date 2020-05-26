# Core Concepts Demos

## Pods

- Create a pod using the imperative commands. Explain each of the outputs of the below commands, as students need to know this to answer questions from labs. For instance, where would you see how many containers a pod has?

```
kubectl run --help
kubectl run --generator=run-pod/v1 nginx --image=nginx
kubectl get pods -o wide
kubectl describe pod nginx
kubectl delete pod nginx
```

- Create a YAML for the pod and inspect it. Here, you'll explain each section in detail.

```
kubectl run --generator=run-pod/v1 nginx --image=nginx --dry-run > nginx.yaml
vim nginx.yaml
kubectl apply -f nginx.yaml
kubectl get pods
kubectl delete -f nginx.yaml
```

- Let's have fun and create a new pod with an incorrect image name. The idea is that you can troubleshoot with students so that they learn how to see the errors, fix the problem, and confirm that everything is working.

```
apiVersion: v1
kind: Pod
metadata:
  name: mc1
spec:
  volumes:
  - name: html
    emptyDir: {}
  containers:
  - name: 1st
    image: ennginxxxxxxxx
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  - name: 2nd
    image: debianssss
    volumeMounts:
    - name: html
      mountPath: /html
    command: ["/bin/sh", "-c"]
    args:
      - while true; do
          date >> /html/index.html;
          sleep 1;
        done
```

## ReplicaSets

Transform a pod into a ReplicaSet. Explain that the key part is the `spec: template:` section, where you simply put the pod specification (including metadata and labels).

- Create a manifest file with the following content:

```
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google_samples/gb-frontend:v3
``` 

- Make sure that you spend time explaining the template, selector, and labels sections above. Now, run the following commands, and explain the outputs to students. 

```
kubectl apply -f frontend.yaml
kubectl get rs
kubectl describe rs/frontend
kubectl get pods
```

- Modify the YAML manifest to change the number of replicas. Alternately, you can use the following command: 

```
kubectl scale --replicas=6 -f frontend.yaml
```

## Deployments

- Create a deployment using the following YAML manifest. Make sure you explain each section of the template.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

- Run the following commands. Explain each of them along with the outputs:

```
kubectl apply -f nginx.yaml
kubectl get deployments
kubectl rollout status deployment.v1.apps/nginx-deployment
kubectl get replicaset
kubectl get pods --show-labels
```

- Let's update the deployment and explain what happens. For example, explain what the `--record` parameter does because this will be crucial for the certification exam. 

```
kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1 --record
kubectl edit deployment.v1.apps/nginx-deployment
kubectl rollout status deployment.v1.apps/nginx-deployment
kubectl get deployments
kubectl get rs
kubectl get pods --show-labels
kubectl describe deployments
```

- Make a change to the deployment, and set an incorrect image name. Roll back to a previous version using the following commands:

```
kubectl set image deployment.v1.apps/nginx-deployment nginx=nginx:1.161 --record=true
kubectl rollout status deployment.v1.apps/nginx-deployment
kubectl get rs
kubectl get pods
kubectl describe deployment
```

```
kubectl rollout history deployment.v1.apps/nginx-deployment
kubectl rollout history deployment.v1.apps/nginx-deployment --revision=2
kubectl rollout undo deployment.v1.apps/nginx-deployment
kubectl get deployment nginx-deployment
kubectl describe deployment nginx-deployment
```

- Use the following command to scale a deployment:

```
kubectl scale deployment.v1.apps/nginx-deployment --replicas=10
```

- You can pause or resume a deployment using the following:

```
kubectl rollout pause deployment.v1.apps/nginx-deployment
kubectl set image deployment.v1.apps/nginx-deployment nginx=nginx:1.16.1

kubectl rollout history deployment.v1.apps/nginx-deployment
kubectl rollout status deployment.v1.apps/nginx-deployment
kubectl get rs

kubectl set resources deployment.v1.apps/nginx-deployment -c=nginx --limits=cpu=200m,memory=512Mi

kubectl rollout resume deployment.v1.apps/nginx-deployment
kubectl get rs -w
```

## Services

- Create a service for the previous deployment object you created, and explain the template in detail. The property `port` is the port the service will use, and the `targetPort` is the port that pods are exposing.

```
apiVersion: v1
kind: Service
metadata:
  name: svc-webapp
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

-  Run the following commands, and explain each of them:

```
kubectl apply -f svc.yaml
kubectl get svc
kubectl get ep
```

- Delete the deployment and create it using imperative commands:

```
kubectl expose deployment nginx-deployment --type=LoadBalancer --name=svc-webapp
kubectl get services
kubectl describe services svc-webapp
kubectl get pods --output=wide
curl http://<external-ip>:<port>
```

- Let's showcase how to use kubectl port-forward. Make sure you adapt the commands with the proper pod IDs.

```
kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-deployment.yaml
kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-service.yaml
kubectl get pod redis-master-765d459796-258hz --template='{{(index (index .spec.containers 0).ports 0).containerPort}}{{"\n"}}'
kubectl port-forward redis-master-765d459796-258hz 7000:6379
redis-cli -p 7000
ping
```

## MultiContainers

- Create a pod with two containers that share a volume; use this YAML:

```
apiVersion: v1
kind: Pod
metadata:
  name: two-containers
spec:

  restartPolicy: Never

  volumes:
  - name: shared-data
    emptyDir: {}

  containers:

  - name: nginx-container
    image: nginx
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html

  - name: debian-container
    image: debian
    volumeMounts:
    - name: shared-data
      mountPath: /pod-data
    command: ["/bin/sh"]
    args: ["-c", "echo Hello from the debian container > /pod-data/index.html"]
```

- What does each container do? The debian container will run a command only, and then it will terminate. Run the following commands, and explain them in detail:

```
kubectl apply -f two-container-pods.yaml
kubectl exec -it two-containers -c nginx-container -- /bin/bash
```

```
root@two-containers:/# apt-get update
root@two-containers:/# apt-get install curl procps
root@two-containers:/# ps aux
root@two-containers:/# curl localhost
```

## Init Containers

- Create a pod that includes an init container. Explain the template in detail:

```
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox:1.28
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox:1.28
    command: ['sh', '-c', "until nslookup myservice.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local; do echo waiting for myservice; sleep 2; done"]
  - name: init-mydb
    image: busybox:1.28
    command: ['sh', '-c', "until nslookup mydb.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local; do echo waiting for mydb; sleep 2; done"]
```

- Run the following commands:

```
kubectl apply -f init.yaml
kubectl get pods
kubectl describe pod init-demo
kubectl logs init-demo -c init-myservice
kubectl logs init-demo -c init-mydb 
```

- Expose the service and database containers:

```
---
apiVersion: v1
kind: Service
metadata:
  name: myservice
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9376
---
apiVersion: v1
kind: Service
metadata:
  name: mydb
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9377
```

- Now, run the following commands:

```
kubectl apply -f services.yaml
kubectl get pods
kubectl describe pod init-demo
```

Another example for configuring a pod that has an init container is this: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-initialization/#creating-a-pod-that-has-an-init-container

## DaemonSet

- Create a DaemonSet with the following specs; explain the YAML template in detail:

```
controllers/daemonset.yaml 

apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      # this toleration is to have the daemonset runnable on master nodes
      # remove it if your masters can't run pods
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

- Verify where the pods are being scheduled.
- Delete a pod to probe that the pod is created again.

## StatefulSet

- Create a StatefulSet by using the following YAML manifest:

```
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx # has to match .spec.template.metadata.labels
  serviceName: "nginx"
  replicas: 3 # by default is 1
  template:
    metadata:
      labels:
        app: nginx # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "my-storage-class"
      resources:
        requests:
          storage: 1Gi
```

- Explain in detail why you need to have a service (for service discovery).
- Spend some time explaining the YAML and what it does in the cluster.
