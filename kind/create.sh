#!/bin/bash

URL=${URL:-"localhost"}
LOCAL_IP_ADDRESS=${LOCAL_IP_ADDRESS:-"10.0.0.4"}
SECONDARY_IP_ADDRESS=${SECONDARY_IP_ADDRESS:-"10.0.1.4"}
DEBIAN_FRONTEND=noninteractive
TOKEN=${TOKEN:-$(uuidgen)}
USERNAME=${USERNAME:-$USER}

prepare_install(){
    sudo apt-get update
    sudo apt-get -y install ca-certificates curl debian-keyring debian-archive-keyring apt-transport-https
    sudo install -m 0755 -d /etc/apt/keyrings
}

install_code_server(){

    echo "Installing code server"
    echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
    sudo apt-get install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f microsoft.gpg

    sudo tee /etc/apt/sources.list.d/vscode.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

    sudo apt-get update
    sudo apt-get install code -y # or code-insiders
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
    sudo groupadd docker
    sudo gpasswd -a $USERNAME docker
    newgrp docker
}

install_kind(){
    echo "Installing Kind"
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
}

install_caddy(){

    echo "Installing Caddy on ${LOCAL_IP_ADDRESS} for https://${URL}"

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    sudo apt-get update
    sudo apt-get install caddy -y

    echo "Creating Caddy config"
    echo -e "$URL {\n\tbind ${LOCAL_IP_ADDRESS}\n\treverse_proxy 127.0.0.1:8080\n}" | sudo tee /etc/caddy/Caddyfile
    sudo systemctl reload caddy
    sudo systemctl restart caddy
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
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
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

run_vscode(){
  sudo tee /usr/lib/systemd/system/code-serve-web@$USERNAME.service <<EOF
[Unit]
Description=vscode-serve-web
After=network.target

[Service]
WorkingDirectory=/home/$USERNAME
Type=exec
ExecStart=/usr/bin/code serve-web --host 127.0.0.1 --port 8080 --accept-server-license-terms --connection-token $TOKEN --log trace
Restart=always
User=%i

[Install]
WantedBy=default.target
EOF
  sudo systemctl enable --now code-serve-web@$USERNAME
  # code serve-web --host 127.0.0.1 --port 8080 --accept-server-license-terms --connection-token $(uuidgen) --log trace 2>&1 & nohup
}

config_user(){
    echo "Configuring user ${USERNAME}"
    sudo usermod -aG docker $USERNAME
    sudo su - $USERNAME
    kind export kubeconfig --name secondkind
}

create_ingress(){
    echo "Creating ingress listening on ${SECONDARY_IP_ADDRESS}"
    kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
}

clone_repo(){
    echo "Cloning repository"
    cd /home/$USERNAME
    sudo -u $USERNAME git clone https://github.com/jmservera/cka
}

prepare_install
command -v code || install_code_server
command -v docker || install_docker
command -v kind || install_kind
command -v caddy || install_caddy
command -v kubectl || install_kubectl
command -v helm || install_helm
config_user
sudo systemctl is-active --quiet code-serve-web@$USERNAME || run_vscode
docker inspect secondkind-control-plane || run_kind
create_ingress
ls /home/$USERNAME/cka || clone_repo