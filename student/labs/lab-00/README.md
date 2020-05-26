# Initial Setup
Before you start with the labs, you need to do a few things in order to be able to connect to your Kubernetes cluster.

## SSH Into the Bastion Host
You need to send the instructor your private and public SSH key to access the bastion and worker nodes.

Retrieve the public key from your new key pair. For more information, see one of these topics in the AWS documentation: [retrieving the public key for your key pair on Linux](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#retrieving-the-public-key) or [retrieving the public key for your key pair on Windows](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#retrieving-the-public-key-windows).

```
ssh-keygen -f ./christian-mac
```

Reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#replacing-key-pair

## Run Basic Commands

```
kubectl version
kubectl get nodes
```
