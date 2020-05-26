# Practice With Deployments

We're assuming that you have previous knowledge about pods in Kubernetes. So, this lab should be a way to remember all the commands and teach you how to troubleshoot common problems. Perform all of the below commands in the Kubernetes cluster we've provisioned for you. No other students have access to this cluster, so feel free to play.

For the following requests, try to use the imperative commands. If not, you can use the YAML manifests, but it's good to practice and feel comfortable with the CLI.

Feel free to use the Kubernetes docs website, as you'll have access to this source in the real life and during the exam as well. We're not including any links here, as the purpose is that you know where and how to find things in the docs site.

- Create a deployment with the name `webapp` using the `nginx` image. Use the labels `tier=frontend`.
- Update the deployment to use a different image like `nginx:1.16.1`.
- Deploy a new version of the web app by setting up an incorrect image name like `nginx:1.16687777`
- See what happens with the pods. Are there any pods running in spite of having an incorrect image?
- Fix the problem by rolling back to the previous version.
- Scale up the deployment to have 10 replicas. Which method did you use? Did you update the object directly using `kubectl edit`, `kubectl scale`, or `kubectl apply`? Be ready to explain each method.
