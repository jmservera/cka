#!/bin/bash

URL=${URL:-"locahost"}
LOCAL_IP_ADDRESS=${LOCAL_IP_ADDRESS:-"10.0.0.4"}
DEBIAN_FRONTEND=noninteractive

prepare_install(){
    sudo apt-get update
    sudo apt-get -y install ca-certificates curl debian-keyring debian-archive-keyring apt-transport-https
    sudo install -m 0755 -d /etc/apt/keyrings
}

install_docker(){
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
}

install_kind(){
    echo "Installing Kind"
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
}

install_caddy(){
    echo "Installing Caddy"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy -y

    echo "Creating Caddy config"
    echo -e "$URL {\n\tbind ${LOCAL_IP_ADDRESS}\n\treverse_proxy 127.0.0.1:8080\n}" | sudo tee /etc/caddy/Caddyfile
}

run_kind(){
    echo "Running Kind"
    docker network create --gateway 172.16.0.1 --subnet=172.16.0.0/16 secondkind
    KIND_EXPERIMENTAL_DOCKER_NETWORK=secondkind kind create cluster --name "secondkind" --config nginx-config.yaml -v 10
}

prepare_install
install_docker
install_kind
install_caddy
run_kind
