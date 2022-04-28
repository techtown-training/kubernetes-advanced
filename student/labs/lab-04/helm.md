# Packaging Applications With Helm

Let's start by installing Helm v3 in your work station or bastion host. You can use the following commands:

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
helm search hub wordpress
```

Add the old official chart repository that contains a lot of stable charts (although notice now most are DEPRECATED):

```
helm repo add stable https://charts.helm.sh/stable
helm search repo
```

Since they are mostly DEPRECATED lets also add bitnami:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search repo mysql
```

Let's install a MySQL database with custom values:

```
helm repo update
helm show values bitnami/mysql
echo '{"image":{"tag":"8.0.27-debian-10-r1"}}' > config.yaml
helm install demo-database -f config.yaml bitnami/mysql
helm ls
kubectl get pods
```

You should be able to connect to the database by using the following commands:

```
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default demo-database-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
echo -e "  Primary: demo-database-mysql.default.svc.cluster.local:3306\n  Username: root\n  Password: $MYSQL_ROOT_PASSWORD"
kubectl run demo-database-mysql-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.27-debian-10-r1 --namespace default --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash
```

Now in the container lets run the mysql client:

```
mysql -h demo-database-mysql.default.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"
```

Verify the MySQL version:

```
SELECT VERSION();
```

Type `exit` a few times to exit first the MySQL client then the container running in the pod.

Change the version of MySQL to a newer version and upgrade the release:

```
sed -i 's/8.0.27/8.0.29/' config.yaml
helm upgrade demo-database -f config.yaml bitnami/mysql
helm ls
kubectl get pods
```

Again verify the version of MySQL

```
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default demo-database-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
kubectl run demo-database-mysql-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.29-debian-10-r1 --namespace default --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash
```

Start the mysql client:

```
mysql -h demo-database-mysql.default.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"
```

```
SELECT VERSION();
```

Type `exit` a few times to exit first the MySQL client then the container running in the pod.

If you want, you could even roll back to the previous version:

```
helm rollback demo-database 1
helm get values demo-database
helm ls
```

We can watch the logs

``` 
POD=$(kubectl get pod -l app.kubernetes.io/instance=demo-database -o jsonpath="{.items[0].metadata.name}")
kubectl logs $POD
```

In this case, the rollback doesn't work because it was a downgrade and the data in the volume is incompatible now.

To uninstall the app, run the following command:

```
helm uninstall demo-database
kubectl get pods
kubectl get svc
```

Now, let's create a Helm package for an existing application:

```
helm create webapp-shop
cd webapp-shop
ls -la
helm lint
cd ../
kubectl create namespace webapp-shop
helm install demo-webapp webapp-shop -n webapp-shop
helm ls -n webapp-shop
kubectl get pods -n webapp-shop
kubectl get svc -n webapp-shop
```

Let's make a change to the service and add the `type: LoadBalancer`. Then, let's deploy a new version of the package:

```
cd webapp-shop
sed -i 's/1.16.0/1.17.0/' Chart.yaml
echo '  type: LoadBalancer' >> templates/service.yaml
cd ..
helm upgrade demo-webapp webapp-shop -n webapp-shop
helm history demo-webapp -n webapp-shop
echo "http://$(kubectl get svc -n webapp-shop -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")"
```

Let's make a new change; this time, we'll use a different image version:

```
cd webapp-shop
sed -i 's/1.17.0/1.17.1/' Chart.yaml
sed -i 's/repository:\snginx/repository: christianhxc\/nginx/g' values.yaml
sed -i 's/tag:\s""/tag: "1.0"/g' values.yaml
cd ..
helm upgrade demo-webapp webapp-shop -n webapp-shop
kubectl get pods -n webapp-shop
helm history demo-webapp -n webapp-shop
echo "http://$(kubectl get svc -n webapp-shop -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")"
```

Let's roll back to the initial version of the application:

```
helm rollback demo-webapp 2 -n webapp-shop
kubectl get pods -n webapp-shop
```

***Note:*** <em>You can't roll back to the previous revision after upgrading a Helm chart from service type ClusterIP to NodePort. Attempts to roll back to the previous revision with a service type ClusterIP will cause the status of the rollback process to be placed in pending.</em>

Delete the application:

```
helm uninstall demo-webapp -n webapp-shop
kubectl get all -n webapp-shop
kubectl delete namespace webapp-shop
```
