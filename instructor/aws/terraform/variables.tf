provider "aws" {
  version = ">= 2.52.0"
  region  = "us-east-1"
  profile = "aspe-instructor"
}

variable "k8s-version" {
  default     = "1.16"
  description = "Kubernetes cluster version"
}

variable "student" {
  default = 0
  description = "Student number index used for VPC CIDR"
}

variable "region" {
  default     = "us-east-1"
  description = "AWS region"
}

locals {
  cluster_name = "eks-terraform-${random_string.suffix.result}"
}