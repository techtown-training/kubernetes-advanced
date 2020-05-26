# Creating the Kubernetes Cluster for Students

- Region: N. Virginia (us-east-1)
- All these scripts used the official AWS reference: https://s3.amazonaws.com/aws-quickstart/quickstart-amazon-eks/doc/amazon-eks-architecture.pdf

## Pre-Work for CloudFormation Templates

Follow these steps if you're starting with a blank AWS account or if you need to create everything from scratch in another region:

- Create an S3 bucket
- Create a folder called "quickstart-amazon-eks"
- Upload all the content in the folder "./base" into the new folder you created
- Create the VPC using the template in the "vpc" folder

## Create Environments for Students

Run the `init.sh` script and configure your AWS credential in the environment first. Perform this task with enough anticipation, as it takes about 30 minutes to create or delete one cluster. However, the script does perform the tasks in parallel. 

Here's an example of how to run the command to create the clusters for five students:

```
$ ./init.sh create 5
$ ./init.sh delete 5
```

Then, you'll have to [install](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html#installing-eksctl) `eksctl` and configure the ASPE Instructor profile as default. For each student cluster, you need to run the following command:

```
$ ./init.sh oidc <<STUDENT_EKSClusterName>>
```

## Adding Students' Keys to Worker Nodes and Bastion Host

You need to ask students to send you the private and public key they want to use to connect to servers. Ideally, they'll create new ones.

When you have the keys, including the one from ASPE, you only need to run the following command for each student:

```
$ ./updatepem.sh 54.145.211.58 /Users/christian/.ssh/aspe-k8s-advanced.pem /Users/christian/christian-mac /Users/christian/christian-mac.pub
```
