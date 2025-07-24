#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    source .env
# else
#     echo "Error: .env file not found"
#     exit 1
fi

SUBNET_PREFIX=${SUBNET_PREFIX:-"10.224.0.0/16"}

sudo sed -i "/swap/s/^/#/" /etc/fstab
sudo swapoff -a

cd /tmp

sudo DEBIAN_FRONTEND=noninteractive apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
sudo DEBIAN_FRONTEND=noninteractive apt-mark hold kubelet kubeadm kubectl





wget https://github.com/containerd/containerd/releases/download/v2.1.3/containerd-2.1.3-linux-amd64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo tar Cxzvf /usr/local containerd-2.1.3-linux-amd64.tar.gz

sudo mkdir -p /usr/local/lib/systemd/system/
sudo cp containerd.service /usr/local/lib/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

wget https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# wget https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
# sudo mkdir -p /opt/cni/bin
# sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.7.1.tgz

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF


sudo modprobe overlay
sudo modprobe br_netfilter

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF


# Install Azure CNI plugin
git clone https://github.com/Azure/azure-container-networking && sudo ./azure-container-networking/scripts/install-cni-plugin.sh v1.6.30 v1.7.1

# Configure Azure CNI plugin with the right default values
cat <<EOF | sudo tee /etc/cni/net.d/10-azure.conflist
{
   "cniVersion":"0.3.0",
   "name":"azure",
   "plugins":[
      {
         "type":"azure-vnet",
         "mode":"transparent",
         "ipsToRouteViaHost":["169.254.20.10"],
         "ipam":{
            "type":"azure-vnet-ipam"
         }
      },
      {
         "type":"portmap",
         "capabilities":{
            "portMappings":true
         },
         "snat":true
      }
   ]
}
EOF

sudo sysctl --system

sudo systemctl enable --now kubelet

sudo DEBIAN_FRONTEND=noninteractive apt install iprange

sudo iptables -t nat -A POSTROUTING -m iprange ! --dst-range 168.63.129.16 -m addrtype ! --dst-type local ! -d $SUBNET_PREFIX -j MASQUERADE

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh	
# --- first 
# sudo kubeadm init --control-plane-endpoint vanillacka.swedencentral.cloudapp.azure.com:6443 --pod-network-cidr  10.224.0.0/16 --upload-certs

# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# kubectl apply -f https://raw.githubusercontent.com/Azure/azure-container-networking/master/npm/azure-npm.yaml


# --- now join

# echo "Run the following command to create the cluster from master 1:"
# echo "      sudo kubeadm init --control-plane-endpoint ${LB_NAME}.$LOCATION.cloudapp.azure.com:6443 --upload-certs"
# echo "or use the join command."

#helm repo add projectcalico https://docs.tigera.io/calico/charts && 
#helm install calico projectcalico/tigera-operator --version v3.26.1 -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico/values.yaml --set-string "installation.calicoNetwork.ipPools[0].cidr=10.224.0.0/16" --namespace "tigera-operator" --create-namespace

