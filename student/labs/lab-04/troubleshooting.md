# Troubleshooting Applications

Let's deploy the following application. Just copy and paste this YAML; don't try to spot the errors:

```
$ kubectl create namespace trouble
$ cat <<EOF | kubectl apply -n trouble -f -
apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: Pod
  metadata:
    labels:
      name: mysql
    name: mysql
  spec:
    containers:
    - env:
      - name: MYSQL_ROOT_PASSWORD
        value: yourstrongpassword
      image: mysql:5.6
      imagePullPolicy: IfNotPresent
      name: mysql
      ports:
      - containerPort: 3306
        protocol: TCP      
- apiVersion: v1
  kind: Service
  metadata:
    name: mysql    
  spec:
    ports:
    - port: 3306
      protocol: TCP
      targetPort: 8080
    selector:
      name: mysql
    type: ClusterIP
- apiVersion: v1
  kind: Service
  metadata:
    name: web-service    
  spec:    
    ports:
    - port: 8080
      protocol: TCP
      targetPort: 8080
    selector:
      name: webapp-mysql
    type: LoadBalancer
- apiVersion: apps/v1
  kind: Deployment
  metadata:    
    labels:
      name: webapp-mysql
    name: webapp-mysql    
  spec:    
    replicas: 1    
    selector:
      matchLabels:
        name: webapp-mysql
    template:
      metadata:
        labels:
          name: webapp-mysql
        name: webapp-mysql
      spec:
        containers:
        - env:
          - name: DB_Host
            value: mysql-service
          - name: DB_User
            value: root
          - name: DB_Password
            value: paswrd
          image: christianhxc/webapp-mysql
          imagePullPolicy: Always
          name: webapp-mysql
          ports:
          - containerPort: 8080
            protocol: TCP
EOF
```

You need to wait some time until the AWS ELB is ready and can receive traffic.

The application flow is the following:

```
user <===> web-service:8080 (service) <===> webapp-mysql:8080 (deployment) <===> mysql-service:3306 (service) <===> mysql:3306 (pod)
``` 

The database credentials should be as follows:

```
- DB_Host = mysql-service
- DB_User = root
- DB_Pass = paswrd
```

There are a few errors you need to fix in the system. You can test if the application is working by accessing the `EXTERNAL IP` of the web app service through a web browser. To make sure you understand how to troubleshoot applications, try to avoid finding the error by reading the previous YAML. Instead, find and fix the error using kubectl only.

Be aware that you might need to recreate some resources.

Here's a list of some useful commands for troubleshooting:

```
$ kubectl get pod $PODNAME -o yaml > pod.yaml
$ kubectl get svc $PODNAME -o yaml > svc.yaml
$ kubectl describe pod $PODNAME
$ kubectl describe svc $SERVICENAME
$ kubectl get endpoints
$ kubectl logs $PODNAME
```

