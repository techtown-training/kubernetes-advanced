# Continuous Delivery With Flux

We already have Istio installed in the cluster with an Ingress gateway, so we'll now focus purely on the application.

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

Here comes the fun part. Create a canary custom resource with the following command:

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
