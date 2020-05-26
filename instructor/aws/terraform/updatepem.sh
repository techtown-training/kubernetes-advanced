#!/bin/bash

# Upload ASPE pem key to bastion host
# Upload student pem key to bastion host
# Update pem key in bastion host with student's pem
# Remove ASPE pem key from bastion host

ssh-keygen -l -f $3
ssh-keygen -l -f $4

scp -i $2 $2 ec2-user@$1:./aspe.pem
scp -i $2 $3 ec2-user@$1:./student.pem
scp -i $2 $4 ec2-user@$1:./student.pub

ssh -i $2 -t ec2-user@$1 "sudo cat student.pub >> ~/.ssh/authorized_keys"

ssh -i $2 -t ec2-user@$1 "sudo mv student.pem ~/.ssh/id_rsa"
ssh -i $2 -t ec2-user@$1 sudo rm -rf aspe.pem
ssh -i $2 -t ec2-user@$1 rm -f student.pub