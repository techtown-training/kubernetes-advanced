# Practice With ReplicaSet

We're assuming that you have previous knowledge about pods in Kubernetes. So, this lab should be a way to remember all the commands and teach you how to troubleshoot common problems. Perform all of the below commands in the Kubernetes cluster we've provisioned for you. No other students have access to this cluster, so feel free to play.

Please have an answer to the following questions ready for the instructor:

- From the previous practice with pods, create a ReplicaSet with three replicas. Remember, you can use the same template from the pod and use it in the template section of the ReplicaSet.
- Delete any of the pods you created with the ReplicaSet. How many pods exist now? Check again.
- Create a ReplicaSet with the following YAML manifest:

```
apiVersion: v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: php
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google_samples/gb-frontend:v3
```

- Read the output. What's wrong with the template? Try to fix it.
- Change the ReplicaSet to use the `redis` image.
- Scale up the ReplicaSet to have 10 pods running.
- Scale down the ReplicaSet to have three pods running.
