# quickstart-amazon-eks
## Modular and Scalable Amazon EKS Architecture

This quick start helps you to deploy a Kubernetes cluster that uses Amazon Elastic Kubernetes Service (Amazon EKS), enabling you to deploy, manage, and scale containerized applications running on Kubernetes on the Amazon Web Services (AWS) Cloud.

Amazon EKS runs the Kubernetes management infrastructure for you across multiple AWS Availability Zones to eliminate a single point of failure. Amazon EKS is also certified Kubernetes conformant, and this reference deployment provides custom resources that enable you to deploy and manage your Kubernetes applications using AWS CloudFormation by declaring Kubernetes manifests or Helm charts directly in AWS CloudFormation templates.

You can use the AWS CloudFormation templates included with this quick start to deploy an Amazon EKS cluster in your AWS account in about 25 minutes. The quick start automates the following:

- Deploying Amazon EKS into a new VPC
- Deploying Amazon EKS into an existing VPC

You can also use the AWS CloudFormation templates as a starting point for your own implementation.

![Quick start architecture for modular and scalable Amazon EKS architecture](https://d0.awsstatic.com/partner-network/QuickStart/datasheets/amazon-eks-on-aws-architecture-diagram.png)

For architectural details, best practices, step-by-step instructions, and customization options, see the [deployment guide](https://fwd.aws/zeWyb).

To post feedback, submit feature ideas, or report bugs, use the **Issues** section of this GitHub repo. If you'd like to submit code for this quick start, please review the [AWS quick start contributor's kit](https://aws-quickstart.github.io/).

Note that you must download Lambda packages manually:
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/Helm/lambda_function.py
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/DeleteBucketContents/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/CfnStackAssumeRole/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/KubeManifest/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/KubeGet/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/KubeConfigUpload/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/CleanupLoadBalancers/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/CleanupSecurityGroupDependencies/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/kubectlLayer/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/helmLayer/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/crhelperLayer/lambda.zip
- https://aws-quickstart.s3.amazonaws.com/quickstart-amazon-eks/functions/packages/GetCallerArn/lambda.zip
