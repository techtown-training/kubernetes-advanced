# Practice With Pods

We're assuming that you have previous knowledge about pods in Kubernetes. So, this lab should be a way to remember all the commands and teach you how to troubleshoot common problems. Perform all of the below commands in the Kubernetes cluster we've provisioned for you. No other students have access to this cluster, so feel free to play.

Please have an answer to the following questions ready for the instructor:

- How many pods exist in the system (all namespaces)?
- How would you create a YAML manifest that creates a pod with an NGNIX image?
- What is the image used for the one of the `coredns-*` pods in the `kube-system` namespace?
- What is the image used for the one of the `kube-proxy-*` pods in the `kube-system` namespace?
- In which nodes are the pods running?

Now, let's start deploying a few sample pods.

- Create a pod with the following specs:

```
apiVersion: v1
kind: Pod
metadata:
  name: mc1
spec:
  volumes:
  - name: html
    emptyDir: {}
  containers:
  - name: 1st
    image: iis:v8
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  - name: 2nd
    image: debian
    volumeMounts:
    - name: html
      mountPath: /html
    command: ["/bin/sh", "-c"]
    args:
      - while true; do
          date >> /html/index.html;
          sleep 1;
        done
```

- Create the pod based on the previous YAML (kubectl apply -f).
- Is it working? If not, fix the problem. Do you need to delete the pod?
- How many nodes are in the `webapp` pod?
- Create a new pod with a container using the image `redis`.
