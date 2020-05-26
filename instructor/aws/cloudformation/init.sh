#!/bin/bash

aws configure --profile aspe-instructor --region us-east-1 --output json
export AWS_DEFAULT_PROFILE=aspe-instructor

if [ $1 = "create" ]; then
  for i in $(eval echo {1..$2}); do
    aws cloudformation deploy --stack-name aspe-kube-adv-student-$i \
    --template-file eks.template.yaml \
    --capabilities "CAPABILITY_IAM" "CAPABILITY_AUTO_EXPAND" \
    --no-fail-on-empty-changeset &
    echo Student Kubernetes cluster "aspe-kube-adv-student-$i" created!
  done
elif [ $1 = "delete" ]; then
  for i in $(eval echo {1..$2}); do
    aws cloudformation delete-stack --stack-name aspe-kube-adv-student-$i &
    echo Student Kubernetes cluster "aspe-kube-adv-student-$i" deleted!
  done
elif [ $1 = "oidc" ]; then
  cluster_name=$2
  eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster $cluster_name --approve
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  OIDC_PROVIDER=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
  aws cloudformation deploy --stack-name aspe-kube-adv-$cluster_name-alb-role \
      --template-file eks.oidc.yaml \
      --parameter-overrides OIDCProvider=$OIDC_PROVIDER \
      --capabilities "CAPABILITY_IAM" "CAPABILITY_AUTO_EXPAND" \
      --no-fail-on-empty-changeset &
else
  echo "You must specify an action like create or delete"
fi
