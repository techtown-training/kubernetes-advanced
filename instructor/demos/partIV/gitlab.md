# CI/CD with GitLab (Incomplete)

Let's start by installing GitLab in the existing Kubernetes cluster:

```
$ kubectl create namespace gitlab
$ helm repo add gitlab https://charts.gitlab.io/
$ helm repo update
$ helm upgrade --install -n gitlab gitlab gitlab/gitlab \
  --timeout 600s \
  --set global.edition=ce \
  --set global.hosts.domain=example.com \
  --set certmanager-issuer.email=me@example.com
$ watch kubectl get pods -n gitlab
```

Wait for all pods to be `Running` or `Completed`.

Because you don't own the `example.com` domain, you'll have to map it locally to a temporary IP from the ELB. If for some reason GitLab stops working, perhaps AWS have recycled the IP, so you'll need to get a new IP using `nslookup`.

Let's map `gitlab.example.com` locally to one of the IPs from the ELB:

```
$ GITLABDNS=$(kubectl get svc -n gitlab gitlab-nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
$ nslookup $GITLABDNS
$ echo "$(nslookup $GITLABDNS | awk -F': ' 'NR==6 { print $2 } ') gitlab.example"
```

Add the output from the last command to your `/etc/hosts` file in your workstation, *NOT in your bastion host*

In a browser, open a new tab with the URL `https://gitlab.example.com` and accept the warning of the certificate, then proceed.

To login, you need to use the `root` username, and to get the password run the following command:

```
$ kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo
```

Create a new project in GitLab, use the name you prefer and choose the "Internal" visibility level.

Go to the "Admin Area" using the URL `https://gitlab.example.com/admin/`, in the left panel click on "Settings" and then click on "Network" link. Then, click on the "Expand" button from the "Outbound requests" section and check the option "Allow requests to the local network from web hooks and services" then click on the "Save changes" button.

Configure your Kubernetes cluster by clicking on "Kubernetes" in the left panel. Click on the "Add Kubernetes cluster" button and then click on the "Add existing cluster" tab.

You need to fill out the form, and to get some of the information run the following commands for each text field:

For the API URL:

```
$ kubectl cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}'
```

For the CA certificate:

```
# Use the default secret under the name of `default-token-xxxxx`
$ kubectl get secrets
$ kubectl get secret default-token-zm8kv -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
```

For the Token:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: gitlab-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: gitlab-admin
  namespace: kube-system
EOF
$ kubectl -n kube-system get secret $(kubectl -n kube-system get secret | grep gitlab-admin | awk '{print $1}') -ojsonpath='{.data.token}' | base64 --decode ; echo
```

Click the "Add Kubernetes cluster" button to save the changes. Then, in the "Base domain" text field, enter "example.com" and click on the "Save changes" button.

## References

- https://docs.bitnami.com/tutorials/create-ci-cd-pipeline-gitlab-kubernetes/
- https://docs.bitnami.com/tutorials/customize-ci-cd-pipeline-gitlab-bitnami-charts/
- https://docs.gitlab.com/ee/user/project/clusters/add_eks_clusters.html#existing-eks-cluster
- https://about.gitlab.com/blog/2019/09/26/building-a-cicd-pipeline-in-20-mins/
- https://itnext.io/deploy-jenkins-with-dynamic-slaves-in-minikube-8aef5404e9c1
- https://www.youtube.com/watch?v=wEDRfAz6_Uw