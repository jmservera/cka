#!/bin/bash

URL=${URL:-"locahost"}
LOCAL_IP_ADDRESS=${LOCAL_IP_ADDRESS:-"10.0.0.4"}
SECONDARY_IP_ADDRESS=${SECONDARY_IP_ADDRESS:-"10.0.1.4"}
DEBIAN_FRONTEND=noninteractive

prepare_install(){
    sudo apt-get update
    sudo apt-get -y install ca-certificates curl debian-keyring debian-archive-keyring apt-transport-https
    sudo install -m 0755 -d /etc/apt/keyrings
}

install_code_server(){
    echo "Installing code server"
    curl -fsSL https://code-server.dev/install.sh | sh
    sudo systemctl enable --now code-server@$USER
}

install_docker(){
    echo "Installing docker"
    # Add Docker's official GPG key:
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    sudo usermod -aG docker $USER
    sudo su - $USER
}

install_kind(){
    echo "Installing Kind"
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
}

install_caddy(){
    echo "Creating Caddy config"
    echo -e "$URL {\n\tbind ${LOCAL_IP_ADDRESS}\n\treverse_proxy 127.0.0.1:8080\n}" | sudo tee /etc/caddy/Caddyfile

    echo "Installing Caddy on ${LOCAL_IP_ADDRESS} for https://${URL}"

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy -y
}

install_kubectl(){
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
}

install_helm(){
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

run_kind(){
    echo "Running Kind on ${SECONDARY_IP_ADDRESS}"
    docker network create --gateway 172.16.0.1 --subnet=172.16.0.0/16 secondkind     
    cat <<EOF | KIND_EXPERIMENTAL_DOCKER_NETWORK=secondkind kind create cluster --name "secondkind" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  # WARNING: It is _strongly_ recommended that you keep this the default
  # (127.0.0.1) for security reasons. However it is possible to change this.
  apiServerAddress: "${SECONDARY_IP_ADDRESS}"
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
    listenAddress: "${SECONDARY_IP_ADDRESS}"
  - containerPort: 443
    hostPort: 443
    protocol: TCP
    listenAddress: "${SECONDARY_IP_ADDRESS}"
- role: worker
  extraMounts:
  - hostPath: /var/lib/kind/worker1
    containerPath: /var/lib/k8s
- role: worker
  extraMounts:
  - hostPath: /var/lib/kind/worker1
    containerPath: /var/lib/k8s
- role: worker
  extraMounts:
  - hostPath: /var/lib/kind/worker1
    containerPath: /var/lib/k8s
EOF
}

create_ingress(){
    echo "Creating ingress listening on ${SECONDARY_IP_ADDRESS}"
    kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
}

prepare_install
install_code_server
install_docker
install_kind
install_caddy
install_kubectl
install_helm
run_kind
create_ingress
