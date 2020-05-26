# Development Workflow in Kubernetes

## Helm: A Kubernetes Package Manager

Let's start by installing Helm v3 in your work station or bastion host, you can use the following commands:

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

Let's make a change to the service and add the `type: LoadBalancer`. Then deploy a new version of the package:

```
$ cd webapp-shop
$ sed -i 's/1.16.0/1.17.0/' Chart.yaml
$ echo '  type: LoadBalancer' >> templates/service.yaml
$ cd ..
$ helm upgrade demo-webapp webapp-shop -n webapp-shop
$ helm history demo-webapp -n webapp-shop
$ echo "http://$(kubectl get svc -n webapp-shop -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")"
```

Let's make a new change and this time use a different image version:

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

***Note:*** <em>You cannot roll back to the previous revision after upgrading a Helm chart from service type ClusterIP to NodePort. Attempts to roll back to the previous revision with a service type ClusterIP will cause the status of the rollback process to be placed in pending.</em>

Delete the application:

```
$ helm uninstall demo-webapp -n webapp-shop
$ kubectl get all -n webapp-shop
$ kubectl delete namespace webapp-shop
```

## Continuous Delivery Using Flux

### Hello World! With Flux

We'll use `fluxctl`, their tool to manage Flux. So, use the following commands:

```
$ wget https://github.com/fluxcd/flux/releases/download/1.19.0/fluxctl_linux_amd64
$ chmod +x fluxctl_linux_amd64
$ sudo mv fluxctl_linux_amd64 /usr/local/bin/fluxctl
$ fluxctl version
```

Fork the getting started repo from Flux to your account in GitHub. The URL is `https://github.com/fluxcd/flux-get-started`.

Now install Flux in your Kubernetes cluster:

```
$ kubectl create ns flux
$ export GHUSER="YOURUSER"
$ fluxctl install \
--git-user=${GHUSER} \
--git-email=${GHUSER}@users.noreply.github.com \
--git-url=git@github.com:${GHUSER}/flux-get-started \
--git-path=namespaces,workloads \
--namespace=flux | kubectl apply -f -
$ kubectl -n flux rollout status deployment/flux
```

Copy the SSH public key that Flux generates and add it to your GitHub account (you can delete it later):

```
$ fluxctl identity --k8s-fwd-ns flux
```

Open GitHub, navigate to your fork, go to `Setting > Deploy keys`. Click on `Add deploy key`, give it a `Title`, check `Allow write access`, paste the Flux public key, and click `Add key`.

Let's do a small change in GitHub. Replace `YOURUSER` in `https://github.com/YOURUSER/flux-get-started/blob/master/workloads/podinfo-dep.yaml` with your GitHub ID. Open the URL in your browser, edit the file, add `--ui-message='Welcome to Flux'` to the container command, and commit the file.

Manually sync the change in Flux, otherwise you'll have to wait five minutes (default):

```
$ fluxctl sync --k8s-fwd-ns flux
$ kubectl get all -n demo
```

Test that the change was applied with the following command:

```
$ kubectl run --generator=run-pod/v1 -n demo test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://podinfo:9898
```

Clean up by removing the `demo` namespace:

```
$ kubectl delete ns demo
```

### Canary Releases With Flagger and Istio

We already have Istio installed in the cluster with an Ingress gateway, so we'll focus now purely in the application.

Install Flagger in Istio by using the following commands:

```
$ helm repo add flagger https://flagger.app
$ kubectl apply -f https://raw.githubusercontent.com/weaveworks/flagger/master/artifacts/flagger/crd.yaml
$ helm upgrade -i flagger flagger/flagger \
--namespace=istio-system \
--set crd.create=false \
--set meshProvider=istio \
--set metricsServer=http://prometheus:9090
```

Create a `demo-flagger` namespace with Istio enabled:

```
$ kubectl create ns demo-flagger
$ kubectl label namespace demo-flagger istio-injection=enabled
```

Deploy the application using the following command:

```
$ cat <<EOF | kubectl apply -n demo-flagger -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webportal
  labels:
    app: webportal  
spec:
  minReadySeconds: 5
  progressDeadlineSeconds: 60
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: webportal
  strategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      annotations:
        prometheus.io/port: "9797"
        prometheus.io/scrape: "true"
      labels:
        app: webportal
    spec:
      containers:
      - command:
        - ./podinfo
        - --port=9898
        - --port-metrics=9797
        - --grpc-port=9999
        - --grpc-service-name=podinfo
        - --level=info
        - --random-delay=false
        - --random-error=false
        env:
        - name: PODINFO_UI_COLOR
          value: '#34577c'
        image: christianhxc/webportal:3.1.0
        imagePullPolicy: IfNotPresent
        livenessProbe:
          exec:
            command:
            - podcli
            - check
            - http
            - localhost:9898/healthz
          initialDelaySeconds: 5
          timeoutSeconds: 5
        name: webportal
        ports:
        - containerPort: 9898
          name: http
          protocol: TCP
        - containerPort: 9797
          name: http-metrics
          protocol: TCP
        - containerPort: 9999
          name: grpc
          protocol: TCP
        readinessProbe:
          exec:
            command:
            - podcli
            - check
            - http
            - localhost:9898/readyz
          initialDelaySeconds: 5
          timeoutSeconds: 5
        resources:
          limits:
            cpu: 2000m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 64Mi
EOF
$ kubectl get pods -n demo-flagger
```

We'll need a way to test the application, so deploy the following testing application:

```
$ cat <<EOF | kubectl apply -n demo-flagger -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flagger-loadtester
  labels:
    app: flagger-loadtester
spec:
  selector:
    matchLabels:
      app: flagger-loadtester
  template:
    metadata:
      labels:
        app: flagger-loadtester
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
        - name: loadtester
          image: christianhxc/flagger-loadtester:0.16.0
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
          command:
            - ./loadtester
            - -port=8080
            - -log-level=info
            - -timeout=1h
          livenessProbe:
            exec:
              command:
                - wget
                - --quiet
                - --tries=1
                - --timeout=4
                - --spider
                - http://localhost:8080/healthz
            timeoutSeconds: 5
          readinessProbe:
            exec:
              command:
                - wget
                - --quiet
                - --tries=1
                - --timeout=4
                - --spider
                - http://localhost:8080/healthz
            timeoutSeconds: 5
          resources:
            limits:
              memory: "512Mi"
              cpu: "1000m"
            requests:
              memory: "32Mi"
              cpu: "10m"
          securityContext:
            readOnlyRootFilesystem: true
            runAsUser: 10001
---
apiVersion: v1
kind: Service
metadata:
  name: flagger-loadtester
  labels:
    app: flagger-loadtester
spec:
  type: ClusterIP
  selector:
    app: flagger-loadtester
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
EOF
$ kubectl get pods -n demo-flagger
```

We need to create a metric template for Istio to collect the latency of services:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: latency
  namespace: istio-system
spec:
  provider:
    type: prometheus
    address: http://prometheus.istio-system:9090
  query: |
    histogram_quantile(
        0.99,
        sum(
            rate(
                istio_request_duration_milliseconds_bucket{
                    reporter="destination",
                    destination_workload_namespace="{{ namespace }}",
                    destination_workload=~"{{ target }}"
                }[{{ interval }}]
            )
        ) by (le)
    )
EOF
```

Here's comes the fun part. Create a canary custom resource with the following command:

```
$ cat <<EOF | kubectl apply -n demo-flagger -f -
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: webportal
spec:
  # deployment reference
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webportal
  # the maximum time in seconds for the canary deployment
  # to make progress before it is rollback (default 600s)
  progressDeadlineSeconds: 60
  service:
    # service port number
    port: 9898
    # container port number or name (optional)
    targetPort: 9898
    # Istio gateways (optional)
    gateways:
    - istio-ingressgateway.istio-system.svc.cluster.local
    # Istio virtual service host names (optional)
    hosts:
    - app.example.com
    # Istio traffic policy (optional)
    trafficPolicy:
      tls:
        # use ISTIO_MUTUAL when mTLS is enabled
        mode: DISABLE
    # Istio retry policy (optional)
    retries:
      attempts: 3
      perTryTimeout: 1s
      retryOn: "gateway-error,connect-failure,refused-stream"
  analysis:
    # schedule interval (default 60s)
    interval: 1m
    # max number of failed metric checks before rollback
    threshold: 5
    # max traffic percentage routed to canary
    # percentage (0-100)
    maxWeight: 50
    # canary increment step
    # percentage (0-100)
    stepWeight: 10
    metrics:
    - name: request-success-rate
      # minimum req success rate (non 5xx responses)
      # percentage (0-100)
      thresholdRange:
        min: 99
      interval: 1m
    - name: latency
      templateRef:
        name: latency
        namespace: istio-system
      thresholdRange:
        max: 500
      interval: 1m
    # testing (optional)
    webhooks:
      - name: acceptance-test
        type: pre-rollout
        url: http://flagger-loadtester.demo-flagger/
        timeout: 30s
        metadata:
          type: bash
          cmd: "curl -sd 'test' http://webportal-canary:9898/token | grep token"
      - name: load-test
        url: http://flagger-loadtester.demo-flagger/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 http://webportal-canary.demo-flagger:9898/"
EOF
$ kubectl get canary -n demo-flagger
$ kubectl -n demo-flagger describe canary/webportal
$ kubectl get pods -n demo-flagger
``` 

Wait some time while the canary is initialized.

Then, let's make a change to the application to trigger the canary promotion:

```
$ kubectl -n demo-flagger set image deployment/webportal webportal=christianhxc/webportal:3.1.1
$ kubectl get canary -n demo-flagger
$ kubectl -n demo-flagger describe canary/webportal
$ kubectl get pods -n demo-flagger
```

If you apply new changes to the deployment during the canary analysis, Flagger will restart the analysis.

A canary deployment is triggered by changes in any of the following objects:
- Deployment PodSpec (container image, command, ports, env, resources, etc.)
- ConfigMaps mounted as volumes or mapped to environment variables
- Secrets mounted as volumes or mapped to environment variables

## Troubleshooting

The following is the working version of the application:

```
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
        value: paswrd
      image: mysql:5.6
      imagePullPolicy: IfNotPresent
      name: mysql
      ports:
      - containerPort: 3306
        protocol: TCP      
- apiVersion: v1
  kind: Service
  metadata:
    name: mysql-service
  spec:
    ports:
    - port: 3306
      protocol: TCP
      targetPort: 3306
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

**Clues:** Make sure the names of the services are correct, ports are configured properly, labels and selectors are properly set, and values for pod env variables are correct.
