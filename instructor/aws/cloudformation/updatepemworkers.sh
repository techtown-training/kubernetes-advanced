#!/bin/bash

NODES=$(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }')
for node in $NODES; do
  ssh-keyscan -H $node >> ~/.ssh/known_hosts
  scp -i aspe.pem student.pub ec2-user@$node:./student.pub
  ssh -i aspe.pem -t ec2-user@$node "cat student.pub >> ~/.ssh/authorized_keys"
  ssh -i aspe.pem -t ec2-user@$node rm student.pub
done