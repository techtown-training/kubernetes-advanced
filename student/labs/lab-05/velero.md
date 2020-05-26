# Back Up and Restore With Velero

First, let's get the name of the S3 bucket assigned to the student from the CloudFormation stack. Get the bucket name from your ./notes.txt in your bastion host.

```
$ export VELERO_BUCKET="aspe-kube-adv-student-1-eksstack-eur-velerobucket-klwqp4amdlmj"
$ export AWS_REGION="us-east-1"
```

Install Velero in the bastion host:

```
$ wget https://github.com/vmware-tanzu/velero/releases/download/v1.3.2/velero-v1.3.2-linux-amd64.tar.gz
$ tar -xvf velero-v1.3.2-linux-amd64.tar.gz -C /tmp
$ sudo mv /tmp/velero-v1.3.2-linux-amd64/velero /usr/local/bin
$ velero version
```

We see an error getting server version because we have not installed Velero on the EKS cluster yet. Let's do exactly that, but before you install Velero, you need to generate the AWS credentials file:

```
$ sudo yum install jq -y
$ IAM_ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
$ CREDENTIALS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAM_ROLE)
$ export VELERO_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
$ export VELERO_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
$ export VELERO_TOKEN=$(echo $CREDENTIALS | jq -r '.Token')
$ cat <<EOF > velero-credentials
[default]
aws_access_key_id=$VELERO_ACCESS_KEY_ID
aws_secret_access_key=$VELERO_SECRET_ACCESS_KEY
aws_session_token=$VELERO_TOKEN
EOF
$ cat velero-credentials
```

For a production cluster, I wouldn't recommend this approach. Instead, you should use service accounts, but we'll talk more about this topic in the upcoming security section of the boot camp.

Install Velero with the following command:

```
$ velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.0.1 \
    --bucket $VELERO_BUCKET \
    --backup-location-config region=$AWS_REGION \
    --snapshot-location-config region=$AWS_REGION \
    --secret-file ./velero-credentials
$ kubectl logs deployment/velero -n velero
$ kubectl get all -n velero
```

Now, let's take a backup of the WordPress site, which is in the "blog" namespace:

```
$ velero backup create blog-backup --include-namespaces blog
$ velero backup describe blog-backup
$ aws s3 ls $VELERO_BUCKET --recursive
```

Call chaos, and delete the "blog" namespace in Kubernetes:

```
$ kubectl delete namespace blog
$ kubectl get all -n blog
```

Let's restore the backup using Velero:

```
$ velero restore create --from-backup blog-backup
$ velero restore get
$ kubectl get all -n blog
$ kubectl get svc -n blog
```

Wait three to five minutes and open in the browser the WordPress site using the svc external IP. Notice that AWS created a new ELB, so the endpoint is different. Therefore, links in WordPress will be broken.

## Clean Up

Clean up by removing the namespace:

```
$ kubectl delete namespace blog
$ kubectl delete namespace/velero clusterrolebinding/velero
$ kubectl delete crds -l component=velero
```
