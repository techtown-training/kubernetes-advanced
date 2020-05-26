terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket = "aspe-kubernetes-advanced-bootcamp-terraform-states"
    key    = "bootcamp/cluster/state"
    region = "us-east-1"
  }
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}
