# Working With Ingress in AWS
For this lab, you'll deploy a Kubernetes Ingress controller using AWS ALB. Next, you'll create a sample application that uses the Ingress controller. Try not to only copy/paste but to understand the YAML manifests because at the end you have a challenge that will confirm you understood the concepts. So, let's start.

Create the Kubernetes service account and cluster role for the Ingress controller using the following YAML manifest:

```
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
rules:
  - apiGroups:
      - ""
      - extensions
    resources:
      - configmaps
      - endpoints
      - events
      - ingresses
      - ingresses/status
      - services
    verbs:
      - create
      - get
      - list
      - update
      - watch
      - patch
  - apiGroups:
      - ""
      - extensions
    resources:
      - nodes
      - pods
      - secrets
      - services
      - namespaces
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: alb-ingress-controller
subjects:
  - kind: ServiceAccount
    name: alb-ingress-controller
    namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
  namespace: kube-system
```

Get the `IAM_ALB_ROLE` ARN from your local ./notes.txt file from your bastion host. Then, attach the role to the Kubernetes role you created before:

```
kubectl annotate serviceaccount -n kube-system alb-ingress-controller eks.amazonaws.com/role-arn=arn:aws:iam::111122223333:role/eks-alb-ingress-controller
```

Deploy the AWS ALB Ingress controller using the following YAML manifest:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: alb-ingress-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: alb-ingress-controller
    spec:
      containers:
        - name: alb-ingress-controller
          args:
            - --ingress-class=alb
          image: docker.io/amazon/aws-alb-ingress-controller:v1.1.4
      serviceAccountName: alb-ingress-controller
```

Open the Kubernetes console editor for the Ingress controller using the following command:

```
kubectl edit deployment.apps/alb-ingress-controller -n kube-system
```

Change the following values with the corresponding ones to your cluster; get values from your local ./notes.txt file from your bastion host.  for the proper values to your setup. Add a line for the cluster name after the `--ingress-class=alb` line. It should look like this:

```
    spec:
      containers:
      - args:
        - --ingress-class=alb
        - --cluster-name=CLUSTER_NAME
        - --aws-vpc-id=VPC_ID
        - --aws-region=us-east-1
```

Confirm that the Ingress controller is still running:

```
kubectl get pods -n kube-system
```

Deploy a sample application using the following YAML manifests:

```
---
apiVersion: v1
kind: Namespace
metadata:
  name: "2048-game"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "2048-deployment"
  namespace: "2048-game"
spec:
  selector:
    matchLabels:
      app: "2048"
  replicas: 5
  template:
    metadata:
      labels:
        app: "2048"
    spec:
      containers:
      - image: alexwhen/docker-2048
        imagePullPolicy: Always
        name: "2048"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: "service-2048"
  namespace: "2048-game"
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: NodePort
  selector:
    app: "2048"
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: "2048-ingress"
  namespace: "2048-game"
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
  labels:
    app: 2048-ingress
spec:
  rules:
    - http:
        paths:
          - path: /*
            backend:
              serviceName: "service-2048"
              servicePort: 80
---
```

Give it a few minutes and get the Ingress CNAME. Test the application:

```
kubectl get ingress/2048-ingress -n 2048-game
```

If something is not working, you can see the Ingress controller logs here:

```
kubectl logs -n kube-system deployment.apps/alb-ingress-controller
```

**Challenge:** Deploy a new application like NGINX using a different port (e.g., 8085) and configure the Ingress object to use the new service you create. When you finish, you should be able to use the same ALB endpoint, but you should see the new app in port 8085.
