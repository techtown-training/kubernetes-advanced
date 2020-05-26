# Packaging Applications With Helm

Let's start by installing Helm v3 in your work station or bastion host. You can use the following commands:

```
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
$ helm version
$ helm search hub wordpress
```

Add the official chart repository that contains a lot of stable charts:

```
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
$ helm search repo
```

Let's install a MySQL database with custom values:

```
$ helm repo update
$ helm show values stable/mysql
$ echo '{imageTag: 5.6.48}' > config.yaml
$ helm install demo-database -f config.yaml stable/mysql
$ helm ls
$ kubectl get pods
```

You should be able to connect to the database by using the following commands:

```
$ PASS=$(kubectl get secrets/demo-database-mysql -o jsonpath='{.data.mysql-root-password}' | base64 --d)
$ POD=$(kubectl get pod -l app=demo-database-mysql -o jsonpath="{.items[0].metadata.name}")
$ echo "MySQL root password is: "$PASS
$ kubectl exec -it $POD -- mysql -h demo-database-mysql -p
Enter password:
mysql> SELECT VERSION();
```

Change the version of MySQL to a newer version and upgrade the release:

```
$ sed -i 's/5.6.48/5.7.30/' config.yaml
$ helm upgrade demo-database -f config.yaml stable/mysql
$ helm ls
$ kubectl get pods
$ POD=$(kubectl get pod -l app=demo-database-mysql -o jsonpath="{.items[0].metadata.name}")
$ PASS=$(kubectl get secrets/demo-database-mysql -o jsonpath='{.data.mysql-root-password}' | base64 --d)
$ echo "MySQL root password is: "$PASS
$ kubectl exec -it $POD -- mysql -h demo-database-mysql -p
Enter password:
mysql> SELECT VERSION();
```

If you want, you could even roll back to the previous version:

```
$ helm rollback demo-database 1
$ helm get values demo-database
$ helm ls
$ POD=$(kubectl get pod -l app=demo-database-mysql -o jsonpath="{.items[0].metadata.name}")
$ kubectl logs $POD
```

In this case, the rollback doesn't work because it was a downgrade and the data in the volume is incompatible now.

To uninstall the app, run the following command:

```
$ helm uninstall demo-database
$ kubectl get pods
$ kubectl get svc
```

Now, let's create a Helm package for an existing application:

```
$ helm create webapp-shop
$ cd webapp-shop
$ ls -la
$ helm lint
$ cd ../
$ kubectl create namespace webapp-shop
$ helm install demo-webapp webapp-shop -n webapp-shop
$ helm ls -n webapp-shop
$ kubectl get pods -n webapp-shop
$ kubectl get svc -n webapp-shop
```

Let's make a change to the service and add the `type: LoadBalancer`. Then, let's deploy a new version of the package:

```
$ cd webapp-shop
$ sed -i 's/1.16.0/1.17.0/' Chart.yaml
$ echo '  type: LoadBalancer' >> templates/service.yaml
$ cd ..
$ helm upgrade demo-webapp webapp-shop -n webapp-shop
$ helm history demo-webapp -n webapp-shop
$ echo "http://$(kubectl get svc -n webapp-shop -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")"
```

Let's make a new change; this time, we'll use a different image version:

```
$ cd webapp-shop
$ sed -i 's/1.17.0/1.17.1/' Chart.yaml
$ sed -i 's/repository:\snginx/repository: christianhxc\/nginx/g' values.yaml
$ sed -i 's/tag:\s""/tag: "1.0"/g' values.yaml
$ cd ..
$ helm upgrade demo-webapp webapp-shop -n webapp-shop
$ kubectl get pods -n webapp-shop
$ helm history demo-webapp -n webapp-shop
$ echo "http://$(kubectl get svc -n webapp-shop -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")"
```

Let's roll back to the initial version of the application:

```
$ helm rollback demo-webapp 2 -n webapp-shop
$ kubectl get pods -n webapp-shop
```

***Note:*** <em>You can't roll back to the previous revision after upgrading a Helm chart from service type ClusterIP to NodePort. Attempts to roll back to the previous revision with a service type ClusterIP will cause the status of the rollback process to be placed in pending.</em>

Delete the application:

```
$ helm uninstall demo-webapp -n webapp-shop
$ kubectl get all -n webapp-shop
$ kubectl delete namespace webapp-shop
```
