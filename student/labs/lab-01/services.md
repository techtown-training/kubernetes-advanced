# Practice With Services

We're assuming that you have previous knowledge about pods in Kubernetes. So, this lab should be a way to remember all the commands and teach you how to troubleshoot common problems. Perform all of the below commands in the Kubernetes cluster we've provisioned for you. No other students have access to this cluster, so feel free to play.

For the following requests, try to use the imperative commands. If not, you can use the YAML manifests, but it's good to practice and feel comfortable with the CLI.

Feel free to use the Kubernetes docs website, as you'll have access to this source in the real life and during the exam as well. We're not including any link here, as the purpose is that you know where and how to find things in the docs site.

- Expose the deployment you created previously by using a `LoadBalancer` service at port `80`.
- Get the `-o wide` details of the new service. Do you see something in particular? Remember, the cluster is running in AWS.
- Change the service to expose the deployment at port `8080`.
- Scale the deployment to 15 replicas. Do you see a change when running `kubectl get ep`?
- Change the service to expose both ports `80` and `8080`. You should be able to access the application publicly.
- Expose your deployment using `port-forward` at port `8585`.
