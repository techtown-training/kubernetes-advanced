#!/bin/bash

aws configure --profile aspe-instructor --region us-east-1 --output json
export AWS_PROFILE=aspe-instructor

terraform init

if [ $1 = "create" ]; then
  for i in $(eval echo {1..$2}); do
    terraform workspace new "aspe-kube-adv-student-$i"
    terraform apply -var "student=$i" -auto-approve
    echo Student Kubernetes cluster "aspe-kube-adv-student-$i" created!
  done
elif [ $1 = "delete" ]; then
  for i in $(eval echo {1..$2}); do
    terraform workspace select "aspe-kube-adv-student-$i"
    terraform destroy -auto-approve
    echo Student Kubernetes cluster "aspe-kube-adv-student-$i" deleted!
  done
else
  echo "You must specify an action like create or delete"
fi