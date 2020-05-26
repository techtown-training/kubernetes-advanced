#!/bin/bash -e

function retry_command() {
    local -r __tries="$1"; shift
    local -r __run="$@"
    local -i __backoff_delay=2

    until $__run
        do
                if (( __current_try == __tries ))
                then
                        echo "Tried $__current_try times and failed!"
                        return 1
                else
                        echo "Retrying ...."
                        sleep $((((__backoff_delay++)) + ((__current_try++))))
                fi
        done

}

function setup_studentnotes(){
  cat > /home/${user}/notes.txt <<EOF
IAM_ALB_ROLE=${IAM_ALB}
CLUSTER_NAME=${K8S_CLUSTER_NAME}
VPC_ID=${VPC_ID}
VELERO_BUCKET=${VELERO_BUCKET}
EOF
}

function setup_kubeconfig() {
    mkdir -p /home/${user}/.kube
    cat > /home/${user}/.kube/config <<EOF
apiVersion: v1
clusters:
- cluster:
    server: ${K8S_ENDPOINT}
    certificate-authority-data: ${K8S_CA_DATA}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${K8S_CLUSTER_NAME}"
EOF
    cp -r /home/${user}/.kube/ /root/.kube/
    chown -R ${user}:${user_group} /home/${user}/.kube/
}

function install_kubernetes_client_tools() {
    mkdir -p /usr/local/bin/
    retry_command 20 curl --retry 5 -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/aws-iam-authenticator
    chmod +x ./aws-iam-authenticator
    mv ./aws-iam-authenticator /usr/local/bin/
    retry_command 20 curl --retry 5 -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/
    cat > /etc/profile.d/kubectl.sh <<EOF
#!/bin/bash
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then     PATH="$PATH:/usr/local/bin";   fi
source <(kubectl completion bash)
EOF
    chmod +x /etc//profile.d/kubectl.sh
}

function install_other_tools(){
  sudo wget https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz
  sudo tar -xzf go1.14.2.linux-amd64.tar.gz -C /home/ec2-user/
  sudo cp -R /home/ec2-user/go /usr/local/
  sudo chown -R ec2-user:ec2-user /home/ec2-user/go
  sudo bash -c 'cat <<EOF > /etc/profile.d/go.sh
export GOROOT=/usr/local/go
export PATH=$PATH:/usr/local/bin/:/usr/local/go/bin
export GOPATH=/home/ec2-user/go
export GOBIN=/usr/local/go/bin
EOF'
  source /etc/profile.d/go.sh
  rm -rf go1.14.2.linux-amd64.tar.gz

  sudo yum install docker -y
  sudo systemctl enable docker
  sudo systemctl restart docker.service
  sudo usermod -aG docker ec2-user
}

install_kubernetes_client_tools
setup_kubeconfig
setup_studentnotes
install_other_tools

echo "Bootstrap complete."