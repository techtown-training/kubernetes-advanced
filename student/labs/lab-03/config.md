# Working With ConfigMaps

Create a ConfigMap to store the background color of the application. Use the following command:

```
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: website
data:
  bgcolor: white
EOF
$ kubectl describe configmap website
```

Use the following YAML manifest and create a deployment object:

```
apiVersion: v1
kind: Pod
metadata:
  name: webapp-color
spec:
  containers:
    - name: webapp
      image: christianhxc/nginx:1.0-color
      imagePullPolicy: Always
      env:
        - name: BGCOLOR
          valueFrom:
            configMapKeyRef:
              name: website
              key: bgcolor
```

Change the background in the ConfigMap, and delete the pod(s) from the deployment you created.

```
$ kubectl edit configmap website
$ kubectl delete pod webapp-color
$ kubectl exec -it webapp-color -- cat /usr/html/index.html
```

If you want, you could expose the deployment through a service and see the new background color in your browser.
