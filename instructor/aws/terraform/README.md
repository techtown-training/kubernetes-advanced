# Creating the Kubernetes Cluster for Students

- Region: N. Virginia (us-east-1)

## Create Environments for Students

Run the `init.sh` script and configure your AWS credential in the environment first. Be sure to start this task within an appropriate time frame, as it takes about 30 minutes to create or delete one cluster. However, the script does perform the tasks in parallel. 

Here's an example of how to run the command to create the clusters for five students:

```
$ ./init.sh create 5
$ ./init.sh delete 5
```

## Adding Students' Keys to Worker Nodes and Bastion Host

You need to ask students to send you the private and public key they want to use to connect to servers. Ideally, they'll create new ones.

When you have the keys, including the one from ASPE, you only need to run the following command for each student:

```
$ ./updatepem.sh 54.145.211.58 /Users/christian/.ssh/aspe-k8s-advanced.pem /Users/christian/christian-mac /Users/christian/christian-mac.pub
```
