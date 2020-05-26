# Security in Kubernetes

We can't cover all the security aspects we discussed, so we'll focus on a few of them only.

## Security Policies

Check that there is at least one existing policy in the cluster, inspect the policy, and notice that by default all authenticated users can create pods in the cluster:

```
$ kubectl get psp
$ kubectl describe psp eks.privileged
$ kubectl describe clusterrolebindings eks:podsecuritypolicy:authenticated
```

Note that if multiple PSPs are available, the Kubernetes admission controller selects the first policy that validates successfully. Policies are ordered alphabetically by their name, and a policy that does not change pod is preferred over mutating policies.

Let's create a namespace, a service account, and a role binding for PSP simulation:

```
$ kubectl create namespace psp-eks-restrictive
$ kubectl -n psp-eks-restrictive create sa eks-test-user
$ kubectl -n psp-eks-restrictive create rolebinding eks-test-editor --clusterrole=edit --serviceaccount=psp-eks-restrictive:eks-test-user
```

Now, to make this lab less verbose, create the following aliases:

```
$ alias kubectl-admin='kubectl -n psp-eks-restrictive'
$ alias kubectl-dev='kubectl --as=system:serviceaccount:psp-eks-restrictive:eks-test-user -n psp-eks-restrictive'
```

Let's create a PSP that disallows the creation of pods using host networking:

```
$ cat <<EOF | kubectl-admin apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: eks.restrictive
spec:
  hostNetwork: false
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - '*'
EOF
$ kubectl get psp
```

Delete the default permissive policy in the cluster along with the cluster role and its binding:

```
$ kubectl delete psp eks.privileged
$ kubectl delete clusterrole eks:podsecuritypolicy:privileged
$ kubectl delete clusterrolebindings eks:podsecuritypolicy:authenticated
$ kubectl get psp
```

Now, let's test that the PSP is working by trying to create a pod that violates the policy:

```
$ kubectl-dev apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  containers:
    - name: busybox
      image: busybox
      command: [ "sh", "-c", "sleep 1h" ]
EOF
```

You should receive an error like this:

```
Error from server (Forbidden): error when creating "STDIN": pods "busybox" is forbidden: unable to validate against any pod security policy: []
```

We have not yet given the developer the appropriate permissions. There is no role binding for the developer user eks-test-user. So, let’s change this by creating a role `psp:unprivileged` for the pod security policy `eks.restrictive`:

```
$ kubectl-admin create role psp:unprivileged --verb=use --resource=podsecuritypolicies.extensions --resource-name=eks.restrictive
$ kubectl-admin create rolebinding eks-test-user:psp:unprivileged --role=psp:unprivileged --serviceaccount=psp-eks-restrictive:eks-test-user
```

Let's create a pod using the developer user:

```
$ kubectl-dev apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  containers:
    - name: busybox
      image: busybox
      command: [ "sh", "-c", "sleep 1h" ]
EOF
$ kubectl-dev get pods
$ kubectl-dev describe pod busybox
```

However, if you create a pod with `hostNetwork: true` you should not be able to do it:

```
$ kubectl-dev apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged
spec:
  hostNetwork: true
  containers:
    - name: busybox
      image: busybox
      command: [ "sh", "-c", "sleep 1h" ]
EOF
```

And that proves that the PSP works.

Finally, to restore the PSP's defaults in the cluster, run the following commands:

``` 
$ cat <<EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:  
  labels:
    eks.amazonaws.com/component: pod-security-policy
    kubernetes.io/cluster-service: "true"
  name: eks.privileged
spec:
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  fsGroup:
    rule: RunAsAny
  hostIPC: true
  hostNetwork: true
  hostPID: true
  hostPorts:
  - max: 65535
    min: 0
  privileged: true
  runAsUser:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  volumes:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:  
  labels:
    eks.amazonaws.com/component: pod-security-policy
    kubernetes.io/cluster-service: "true"
  name: eks:podsecuritypolicy:privileged
rules:
- apiGroups:
  - policy
  resourceNames:
  - eks.privileged
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:    
    kubernetes.io/description: Allow all authenticated users to create privileged
      pods.  
  labels:
    eks.amazonaws.com/component: pod-security-policy
    kubernetes.io/cluster-service: "true"
  name: eks:podsecuritypolicy:authenticated  
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: eks:podsecuritypolicy:privileged
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:authenticated
EOF
$ kubectl delete ns psp-eks-restrictive
$ kubectl delete psp eks.restrictive
$ unalias kubectl-admin
$ unalias kubectl-dev
```

## Secrets

Let's create secret and then use it within a pod. Your EKS cluster is using an AWS KMS key to encrypt etcd.

So, run the following commands to create the secret:

```
$ kubectl create ns security
$ echo -n "secretkey: QOIUELKJASDF@@#$@#$" > ./credentials
$ kubectl create secret generic credentials --from-file=credentials=./credentials -n security
```

Then, view its content:

```
$ kubectl get secret credentials -o jsonpath="{.data.credentials}" -n security | base64 --decode
```

From your perspective, this looks exactly the same, but if you were in AWS CloudTrail, you could see that the decrypt process used KMS.

```
$ kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-using-secret
  namespace: security
spec:
  containers:
  - name: shell
    image: amazonlinux:2018.03
    command:
      - "bin/bash"
      - "-c"
      - "cat /tmp/credentials && sleep 10000"
    volumeMounts:
      - name: sec
        mountPath: "/tmp"
        readOnly: true
  volumes:
  - name: sec
    secret:
      secretName: credentials
EOF
$ kubectl get pods -n security
$ kubectl -n security exec -it app-using-secret -- cat /tmp/credentials
```

## Sealed Secrets

Let's start by installing `kubeseal` in the bastion host:

```
$ wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.12.2/kubeseal-linux-amd64 -O kubeseal
$ sudo install -m 755 kubeseal /usr/local/bin/kubeseal
$ kubeseal --version
```

Now, install the CRD in the cluster. When you see the pod's logs, you'll sse the key pair to unseal secrets:

```
$ kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.12.2/controller.yaml
$ kubectl get pods -n kube-system | grep sealed-secrets-controller
$ kubectl logs sealed-secrets-controller-86b6989b4f-p8srg -n kube-system
```

When you take a closer look at the controller logs, you'll notice that it creates a secret that contains the public key information:

```
$ kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml
```

Now it's time to seal secrets and use them in pods. But first, let's get rid of the secret you created previously:

```
$ kubectl delete secret credentials -n security
```

Let's create the SealedSecret YAML manifest with a backup of the `credentials` secret. Run the following commands:

```
$ cat <<EOF > credentials.yaml
apiVersion: v1
data:
  credentials: c2VjcmV0a2V5OiBRT0lVRUxLSkFTREZAQCMjJA==
kind: Secret
metadata:
  name: credentials
  namespace: security
type: Opaque
EOF
$ kubeseal --format=yaml < credentials.yaml > sealed-credentials.yaml
$ cat credentials.yaml
$ cat sealed-credentials.yaml
```

Notice that the key name `credentials` in the original Secret is not encrypted in the SealedSecret; only its value is encrypted.

Create the sealed secret in Kubernetes:

```
$ kubectl apply -f sealed-credentials.yaml 
$ kubectl logs sealed-secrets-controller-86b6989b4f-p8srg -n kube-system
$ kubectl get secrets -n security
```

Let's redeploy the pod and confirm that everything is working:

```
$ kubectl delete pod app-using-secret -n security
$ kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-using-secret
  namespace: security
spec:
  containers:
  - name: shell
    image: amazonlinux:2018.03
    command:
      - "bin/bash"
      - "-c"
      - "cat /tmp/credentials && sleep 10000"
    volumeMounts:
      - name: sec
        mountPath: "/tmp"
        readOnly: true
  volumes:
  - name: sec
    secret:
      secretName: credentials
EOF
$ kubectl get pods -n security
$ kubectl -n security exec -it app-using-secret -- cat /tmp/credentials
```

This way, you now could store your YAML templates for secrets because in your deployment pipeline you'll seal them using `kubeseal`.
