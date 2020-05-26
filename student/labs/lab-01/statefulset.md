# Working With StatefulSet

You're going to create a workload to collect logs from an application and send the logs to Elasticsearch using Fluentd. You'll then explore the logs using Kibana. When you finish with the lab, make sure you share the Kibana service URL so the instructor can verify that you completed the lab.

- Create a namespace dedicated for this workload:

```
kubectl create namespace kube-logging
```

- Create a headless service for Elasticsearch using the following YAML manifest:

```
kind: Service
apiVersion: v1
metadata:
  name: elasticsearch
  namespace: kube-logging
  labels:
    app: elasticsearch
spec:
  selector:
    app: elasticsearch
  clusterIP: None
  ports:
    - port: 9200
      name: rest
    - port: 9300
      name: inter-node
```

- Create the StatefulSet for Elasticsearch using the following YAML manifest. Pay close attention to each of these different sections: `containers`, `initContainers`, and `volumeClaimTemplates`.

```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: kube-logging
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.2.0
        resources:
            limits:
              cpu: 1000m
            requests:
              cpu: 100m
        ports:
        - containerPort: 9200
          name: rest
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        env:
          - name: cluster.name
            value: k8s-logs
          - name: node.name
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: discovery.seed_hosts
            value: "es-cluster-0.elasticsearch,es-cluster-1.elasticsearch,es-cluster-2.elasticsearch"
          - name: cluster.initial_master_nodes
            value: "es-cluster-0,es-cluster-1,es-cluster-2"
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx512m"
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: increase-fd-ulimit
        image: busybox
        command: ["sh", "-c", "ulimit -n 65536"]
        securityContext:
          privileged: true
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: gp2
      resources:
        requests:
          storage: 100Gi
```

- Monitor how the pods are being scheduled:

```
kubectl rollout status sts/es-cluster --namespace=kube-logging
```

- Confirm that the Elasticsearch cluster is working by implementing a local port forwarding:

```
kubectl port-forward es-cluster-0 9200:9200 --namespace=kube-logging
```

- In a separate tab or window in the bastion host, run the following command:

```
curl http://localhost:9200/_cluster/state?pretty
```

- Now create the Kibana resources using the following YAML manifest:

```
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  type: LoadBalancer
  ports:
  - port: 5601
  selector:
    app: kibana
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:7.2.0
        resources:
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        env:
          - name: ELASTICSEARCH_URL
            value: http://elasticsearch:9200
        ports:
        - containerPort: 5601
```

- Confirm that everything is working by using the following commands:

```
kubectl rollout status deployment/kibana --namespace=kube-logging
kubectl get pods --namespace=kube-logging
```

- Get the `EXTERNAL-IP` for the Kibana service by running the following command:

```
kubectl get svc -n kube-logging
```

- You'll need to wait about three minutes for pods to be in service. Then, you can open your browser with an URL like this: `http://ad7e5f7e083504f8fa131bcdf256d592-294521320.us-east-1.elb.amazonaws.com:5601/
`. The long name you see there is the value from the `EXTERNAL-IP` column from the previous command. Click on the "Explore my own" button. ***Don't close this window; you'll use it later***.

- Create the Fluentd resources by using the following YAML manifest:

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: kube-logging
  labels:
    app: fluentd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
  labels:
    app: fluentd
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - namespaces
  verbs:
  - get
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: kube-logging
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-logging
  labels:
    app: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.4.2-debian-elasticsearch-1.1
        env:
          - name:  FLUENT_ELASTICSEARCH_HOST
            value: "elasticsearch.kube-logging.svc.cluster.local"
          - name:  FLUENT_ELASTICSEARCH_PORT
            value: "9200"
          - name: FLUENT_ELASTICSEARCH_SCHEME
            value: "http"
          - name: FLUENTD_SYSTEMD_CONF
            value: disable
        resources:
          limits:
            memory: 512Mi
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

- Wait until all pods are running. You can check the status with the following command:

```
kubectl get ds --namespace=kube-logging
kubectl get pods --namespace=kube-logging
```

- Go back to the Kibana window. In the left menu, click on "Discover". Then, in the `Index pattern` text box, enter `logstash-*` and click on the `> Next step` button. In the next screen, pick `@timestamp` for the `Time Filter field name` drop-down menu and click on the `Create index pattern` button. Go back to the "Discover" page, and you should see some logs.

- Let's put into practice how to read the logs from a pod. Create a pod using the following YAML manifest:

```
apiVersion: v1
kind: Pod
metadata:
  name: counter
spec:
  containers:
  - name: count
    image: busybox
    args: [/bin/sh, -c,
            'i=0; while true; do echo "$i: $(date)"; i=$((i+1)); sleep 1; done']
```

- Go back to Kibana, and on the "Discover" page, type `kubernetes.pod_name:counter` in the `Filters` field. Next, click on the `Refresh` button. You should see some logs from the pod.
