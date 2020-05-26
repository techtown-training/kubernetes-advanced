# Working With PV and PVC

We're going to deploy WordPress because it uses MySQL as a database.

Let's first create a namespace and a secret to store the MySQL password:

```
$ kubectl create namespace blog
$ kubectl create secret generic mysql-pass --from-literal=username='my-app' --from-literal=password='Sup3rS3cr3tP@@s!' -n blog
```

Create a PVC for MySQL. We don't need to create a PV first because the cluster is using AWS EBS as the StorageClass, so when you create a PVC the volume is created dynamically using the StorageClass by default in the cluster. Run the following commands:

```
$ kubectl get storageclass
$ cat <<EOF | kubectl apply -n blog -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
  labels:
    app: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
EOF
$ kubectl get pvc -n blog
```

Notice the PVC status is "Pending" because no pod has claimed it yet.

Let's create the MySQL deployment object that uses the PVC you just created as well as the secret for the DB's password. Notice that the pod creates a volume at `/var/lib/mysql`:

```
$ cat <<EOF | kubectl apply -n blog -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: mysql
    spec:
      containers:
      - image: mysql:5.6
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim
EOF
$ kubectl get pods -n blog
$ kubectl get pvc -n blog
```

Now the PVC status is "Bound" because there's a pod using it.

Let's create a service to expose the MySQL deployment:

```
$ cat <<EOF | kubectl apply -n blog -f -
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
spec:
  ports:
    - port: 3306
  selector:
    app: wordpress
    tier: mysql
  clusterIP: None
EOF
$ kubectl get pods -n blog -o wide
$ kubectl get svc -n blog
$ kubectl get ep -n blog
```

Let's deploy WordPress. To start, create the PVC for the WordPress data files:

```
$ cat <<EOF | kubectl apply -n blog -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pv-claim
  labels:
    app: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
EOF
$ kubectl get pvc -n blog
``` 

We'll use volumes here for the website data files as well, and we'll use the DB's secret for the password:

```
$ cat <<EOF | kubectl apply -n blog -f -
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
      - image: wordpress:4.8-apache
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pv-claim
EOF
$ kubectl get pods -n blog
$ kubectl get pvc -n blog
```

Let's expose the WordPress site publicly by creating a service:

```
$ cat <<EOF | kubectl apply -n blog -f -
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: LoadBalancer
EOF
$ kubectl get svc -n blog
```

Remember, you'll need to wait a few minutes before you can access the site. AWS needs to finish creating the ELB.

When you can access WordPress using a browser, configure it and create a new post.

Then, delete all pods manually, and Kubernetes will create new pods:

```
$ kubectl delete --all pods -n blog
$ kubectl get pods -n blog
$ kubectl get pvc -n blog
```

Visit the WordPress site again. All the data should still be there.
