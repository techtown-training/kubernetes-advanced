# Service Mesh With Istio

## Installing Istio

Let's start by installing Istio 1.5.2 and deploying the sample application:

```
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.5.2
export PATH=$PWD/bin:$PATH
istioctl manifest apply --set profile=demo
kubectl create namespace servicemesh
kubectl label namespace servicemesh istio-injection=enabled
```

Deploy the sample application using the following YAML manifest:

```
apiVersion: v1
kind: Service
metadata:
  name: details
  labels:
    app: details
    service: details
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: details
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-details
  labels:
    account: details
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: details-v1
  labels:
    app: details
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: details
      version: v1
  template:
    metadata:
      labels:
        app: details
        version: v1
    spec:
      serviceAccountName: bookinfo-details
      containers:
      - name: details
        image: docker.io/istio/examples-bookinfo-details-v1:1.15.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: Service
metadata:
  name: ratings
  labels:
    app: ratings
    service: ratings
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: ratings
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-ratings
  labels:
    account: ratings
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratings-v1
  labels:
    app: ratings
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ratings
      version: v1
  template:
    metadata:
      labels:
        app: ratings
        version: v1
    spec:
      serviceAccountName: bookinfo-ratings
      containers:
      - name: ratings
        image: docker.io/istio/examples-bookinfo-ratings-v1:1.15.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: Service
metadata:
  name: reviews
  labels:
    app: reviews
    service: reviews
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: reviews
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-reviews
  labels:
    account: reviews
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v1
  labels:
    app: reviews
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v1
  template:
    metadata:
      labels:
        app: reviews
        version: v1
    spec:
      serviceAccountName: bookinfo-reviews
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v1:1.15.0
        imagePullPolicy: IfNotPresent
        env:
        - name: LOG_DIR
          value: "/tmp/logs"
        ports:
        - containerPort: 9080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: wlp-output
          mountPath: /opt/ibm/wlp/output
      volumes:
      - name: wlp-output
        emptyDir: {}
      - name: tmp
        emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v2
  labels:
    app: reviews
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v2
  template:
    metadata:
      labels:
        app: reviews
        version: v2
    spec:
      serviceAccountName: bookinfo-reviews
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v2:1.15.0
        imagePullPolicy: IfNotPresent
        env:
        - name: LOG_DIR
          value: "/tmp/logs"
        ports:
        - containerPort: 9080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: wlp-output
          mountPath: /opt/ibm/wlp/output
      volumes:
      - name: wlp-output
        emptyDir: {}
      - name: tmp
        emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reviews-v3
  labels:
    app: reviews
    version: v3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v3
  template:
    metadata:
      labels:
        app: reviews
        version: v3
    spec:
      serviceAccountName: bookinfo-reviews
      containers:
      - name: reviews
        image: docker.io/istio/examples-bookinfo-reviews-v3:1.15.0
        imagePullPolicy: IfNotPresent
        env:
        - name: LOG_DIR
          value: "/tmp/logs"
        ports:
        - containerPort: 9080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: wlp-output
          mountPath: /opt/ibm/wlp/output
      volumes:
      - name: wlp-output
        emptyDir: {}
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: productpage
  labels:
    app: productpage
    service: productpage
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: productpage
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookinfo-productpage
  labels:
    account: productpage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage-v1
  labels:
    app: productpage
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
      version: v1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      serviceAccountName: bookinfo-productpage
      containers:
      - name: productpage
        image: docker.io/istio/examples-bookinfo-productpage-v1:1.15.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
---
```

Remember to deploy the app in the "servicemesh" namespace:

```
kubectl apply -f istiodemo.yaml -n servicemesh
kubectl get svc -n servicemesh
kubectl get pods -n servicemesh
kubectl exec -n servicemesh -it $(kubectl get pod -n servicemesh -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
```

Make the app accessible by creating an ingress gateway using the following YAML manifest:

```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
```

Remember, you need to create the resources in the "servicemesh" namespace:

```
kubectl apply -f istioingress.yaml -n servicemesh
kubectl get gateway -n servicemesh
kubectl get svc istio-ingressgateway -n istio-system
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo http://$GATEWAY_URL/productpage
```

Let's expose Kiali to access it via the internet:

```
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: kiali-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15029
      name: http-kiali
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: kiali-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - kiali-gateway
  http:
  - match:
    - port: 15029
    route:
    - destination:
        host: kiali
        port:
          number: 20001
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: kiali
  namespace: istio-system
spec:
  host: kiali
  trafficPolicy:
    tls:
      mode: DISABLE
---
EOF
```

Get Kiali's URL, and access Kiali using the default credentials (username: admin | password: admin). Then, go to "Graph" in the left menu, and choose "servicemesh" from the "Namespace" dropdown menu. You can get the URL using the following command:

```
echo http://$GATEWAY_URL:15029/
```

## Deploying Another Application

We'll use a simple application to play with a few features from Istio. 

Create a namespace dedicated to the new app, and make sure you enable it for Istio:

```
kubectl create namespace portal
kubectl label namespace portal istio-injection=enabled
```

Use the following YAML manifest to deploy a three services app:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: customer
    version: v1
  name: customer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: customer
      version: v1
  template:
    metadata:
      labels:
        app: customer
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - env:
        - name: JAVA_OPTIONS
          value: -Xms15m -Xmx15m -Xmn15m
        name: customer
        image: christianhxc/portal-customer:v1
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 8778
          name: jolokia
          protocol: TCP
        - containerPort: 9779
          name: prometheus
          protocol: TCP
        resources:
          requests:
            memory: "20Mi"
            cpu: "200m" # 1/5 core
          limits:
            memory: "40Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - curl
            - localhost:8080/health/live
          initialDelaySeconds: 5
          periodSeconds: 4
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command:
            - curl
            - localhost:8080/health/ready
          initialDelaySeconds: 6
          periodSeconds: 5
          timeoutSeconds: 1
        securityContext:
          privileged: false
---
apiVersion: v1
kind: Service
metadata:
  name: customer
  labels:
    app: customer
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: customer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: preference
    version: v1
  name: preference-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: preference
      version: v1
  template:
    metadata:
      labels:
        app: preference
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - env:
        - name: JAVA_OPTIONS
          value: -Xms15m -Xmx15m -Xmn15m
        name: preference
        image: christianhxc/portal-preference:v1
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 8778
          name: jolokia
          protocol: TCP
        - containerPort: 9779
          name: prometheus
          protocol: TCP
        resources:
          requests:
            memory: "20Mi"
            cpu: "200m" # 1/5 core
          limits:
            memory: "40Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - curl
            - localhost:8080/health/live
          initialDelaySeconds: 5
          periodSeconds: 4
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command:
            - curl
            - localhost:8080/health/ready
          initialDelaySeconds: 6
          periodSeconds: 5
          timeoutSeconds: 1
        securityContext:
          privileged: false
---
apiVersion: v1
kind: Service
metadata:
  name: preference
  labels:
    app: preference
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: preference
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: recommendation
    version: v1
  name: recommendation-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: recommendation
      version: v1
  template:
    metadata:
      labels:
        app: recommendation
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - env:
        - name: JAVA_OPTIONS
          value: -Xms15m -Xmx15m -Xmn15m
        name: recommendation
        image: christianhxc/portal-recommendation:v1
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 8778
          name: jolokia
          protocol: TCP
        - containerPort: 9779
          name: prometheus
          protocol: TCP
        resources:
          requests:
            memory: "40Mi"
            cpu: "200m" # 1/5 core
          limits:
            memory: "100Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - curl
            - localhost:8080/health/live
          initialDelaySeconds: 5
          periodSeconds: 4
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command:
            - curl
            - localhost:8080/health/ready
          initialDelaySeconds: 6
          periodSeconds: 5
          timeoutSeconds: 1
        securityContext:
          privileged: false
---
apiVersion: v1
kind: Service
metadata:
  name: recommendation
  labels:
    app: recommendation
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: recommendation
---
```

Make sure you create the app in the "portal" namespace:

```
kubectl apply -f portalapp.yaml -n portal
```

Use the following commands to confirm that everything is working when pods are "Running":

```
$ kubectl get pods -n portal
$ kubectl run --generator=run-pod/v1 -n portal test-$RANDOM --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://customer.portal.svc.cluster.local:8080
```

## Controlling Canary Deployments With Istio

Let's deploy a v2 of the recommendation service. Use the following YAML manifest:

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: recommendation
    version: v2
  name: recommendation-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: recommendation
      version: v2
  template:
    metadata:
      labels:
        app: recommendation
        version: v2
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - env:
        - name: JAVA_OPTIONS
          value: -Xms15m -Xmx15m -Xmn15m
        image: christianhxc/portal-recommendation:v2
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: "/health"
            port: 8080       
          initialDelaySeconds: 3
          periodSeconds: 5
          timeoutSeconds: 5
        name: recommendation
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 8778
          name: jolokia
          protocol: TCP
        - containerPort: 9779
          name: prometheus
          protocol: TCP
        readinessProbe:
          httpGet:
            path: "/health"
            port: 8080      
          initialDelaySeconds: 3
          periodSeconds: 5
          timeoutSeconds: 5
        securityContext:
          privileged: false
```

Remember, you need to create the new deployment in the "portal" namespace:

```
kubectl apply -f recommendationv2.yaml -n portal
kubectl get pods -n portal
```

Open a new tab, and run the following command to test the traffic. Don't close the tab, as you'll continue using it:

```
$ kubectl run --generator=run-pod/v1 -n portal test-$RANDOM --rm -i -t --image=alpine -- sh
/ # cat <<EOF > test.sh
#!/bin/sh 
while true
do wget -qO- --timeout=2 http://customer.portal.svc.cluster.local:8080
sleep .1
done
EOF
/ # sh ./test.sh
```

Create the default `DestinationRule` and `VirtualService` to redirect all traffic to v1. Use the following YAML manifest:

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: recommendation
spec:
  host: recommendation
  subsets:
  - labels:
      version: v1
    name: version-v1
  - labels:
      version: v2
    name: version-v2
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: recommendation
spec:
  hosts:
  - recommendation
  http:
  - route:
    - destination:
        host: recommendation
        subset: version-v1
      weight: 90
```

Make sure to create the resources in the "portal" namespace:

```
kubectl apply -f istiotraffic.yaml -n portal
```

Go to the tab where you were testing the traffic, and run the test again. You'll see that the traffic now only goes to v1.

Modify the YAML file you used to create the `VirtualService`, and add the following lines at the end of the file. Remember, you need to run the `kubectl apply` in the "portal" namespace:

```
    - destination:
        host: recommendation
        subset: version-v2
      weight: 10
```

Apply the change, and run the traffic test again. You should see that only a fraction of the traffic is being sent to v2.

Continue modifying the `VirtualService`, and run the traffic test until you finish the full rollout.

## Explore Your Application

Enable the telemetry endpoint to be accessed over the internet running the following command:

```
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: tracing-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15032
      name: http-tracing
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: tracing-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - tracing-gateway
  http:
  - match:
    - port: 15032
    route:
    - destination:
        host: tracing
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: tracing
  namespace: istio-system
spec:
  host: tracing
  trafficPolicy:
    tls:
      mode: DISABLE
---
EOF
```

You can use the Jaeger Operator to see traces for all your pods. Let's get the tracing URL by running the following command.

```
echo http://$GATEWAY_URL:15032/
```

In the left sidebar, choose "customer" from the "Service" drop-down menu, and you should see some traces.

You also have access to Grafana. Run the following command to enable public access:

```
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: grafana-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15031
      name: http-grafana
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grafana-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - grafana-gateway
  http:
  - match:
    - port: 15031
    route:
    - destination:
        host: grafana
        port:
          number: 3000
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: grafana
  namespace: istio-system
spec:
  host: grafana
  trafficPolicy:
    tls:
      mode: DISABLE
---
EOF
```

You can use Grafana to see metrics from all your pods. Let's get the Grafana URL by running the following command:

```
echo http://$GATEWAY_URL:15031/
```

Make sure to select the "Istio Workload Dashboard" in the upper-left of the Grafana dashboard. You can change the time range in the upper-right and choose "Last 1 hour" or more.
