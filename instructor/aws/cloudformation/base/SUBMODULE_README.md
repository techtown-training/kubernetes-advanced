# Reusing Amazon EKS quick start as a component in your own project

This quick start is designed as a framework for deploying Kubernetes-based applications into Amazon EKS using AWS 
CloudFormation. It can be used for the following:

* To provide three possible entry points
  * New VPC and EKS cluster
  * Existing VPC new EKS cluster
  * Existing VPC and Kubernetes cluster
* To provide custom resource types
  * KubeManifest - create, update, and delete Kubernetes resources using Kubernetes manifests natively in CloudFormation. 
  Can auto-generate names and provides metadata in Kubernetes API response as return values
  * Helm - use CloudFormation to install applications using Helm charts. Supports custom repos and passing values to 
  charts. Output includes release name and names of all created resources.
* To stabilize resources - wait for resources to complete before returning; this enables timing to be controlled between 
dependent application components
* To serve as a submodule base for Kubernetes applications
* To provide a bastion host already configured with kubectl, helm, and kubeconfig
* To create an EKS cluster and node group, including a role that has access to the cluster and can be assumed by lambda

## Testing

1. Create EC2 key pair
1. Set `KeyPairName` as a [global TaskCat override](https://aws-quickstart.github.io/input-files.html#parm-override)
1. Deploy `amazon-eks-master.template.yaml` using TaskCat `cd quickstart-amazon-eks ; taskcat -v -n -c ./ci/config.yml`
1. Launch example workload template `example-workload.template.yaml`; needed parameters can be retrieved from outputs of 
the master stack
1. SSH into bastion host; validate that example `ConfigMap` (created by Kubernetes manifest) and 
`service-catalog` (created by helm install) have installed correctly
 
## Using as submodule

You can use the `amazon-eks-master.template.yaml`, `amazon-eks-master-existing-vpc.template.yaml`, and 
`amazon-eks-master-existing-cluster.template.yaml` files as a starting point for building your own templates, updating the 
paths in both to point to the EKS submodule for all needed templates and adding a workload template to 
`amazon-eks-master-existing-vpc.template.yaml` (you can use `example-workload.template.yaml` as a starting point for this).
