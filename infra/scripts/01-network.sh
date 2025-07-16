#!/bin/bash

az network vnet create \
    -g $RG_NAME \
    --name kubeadm \
    --address-prefix 192.168.0.0/16 \
    --subnet-name kube \
    --subnet-prefix 192.168.0.0/16

az network nsg create \
    -g $RG_NAME \
    --name kubeadm

# az network nsg rule create \
#     -g $RG_NAME \
#     --nsg-name kubeadm \
#     --name kubeadmssh \
#     --protocol tcp \
#     --priority 1000 \
#     --destination-port-range 22 \
#     --access allow

az network nsg rule create \
    -g $RG_NAME \
    --nsg-name kubeadm \
    --name kubeadmWeb \
    --protocol tcp \
    --priority 1001 \
    --destination-port-range 6443 \
    --access allow

az network vnet subnet update \
    -g kubeadm \
    -n kube \
    --vnet-name kubeadm \
    --network-security-group kubeadm

az network vnet subnet create \
        --resource-group $RG_NAME \
        --vnet-name kubeadm \
        --name kubeadm-gw \
        --address-prefix 192.168.1.0/24

az network public-ip create \
    --resource-group $RG_NAME \
    --name controlplaneip \
    --sku Standard \
    --dns-name vanilla$RG_NAME

 az network lb create \
    --resource-group $RG_NAME \
    --name kubemaster \
    --sku Standard \
    --public-ip-address controlplaneip \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes     

az network lb probe create \
    --resource-group $RG_NAME \
    --lb-name kubemaster \
    --name kubemasterweb \
    --protocol tcp \
    --port 6443   

az network lb rule create \
    --resource-group $RG_NAME \
    --lb-name kubemaster \
    --name kubemaster \
    --protocol tcp \
    --frontend-port 6443 \
    --backend-port 6443 \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes \
    --probe-name kubemasterweb \
    --disable-outbound-snat true \
    --idle-timeout 15 \
    --enable-tcp-reset true


for i in $(seq 1 $MASTER_COUNT); do
    az network nic ip-config address-pool add \
        --address-pool masternodes \
        --ip-config-name ipconfigkube-master-$i \
        --nic-name kube-master-${i}VMNic \
        --resource-group $RG_NAME \
        --lb-name kubemaster
done

# Create NAT gateway public IP
az network public-ip create \
    --resource-group $RG_NAME \
    --name natgateway-ip \
    --sku Standard \
    --allocation-method Static

# Create NAT gateway
az network nat gateway create \
    --resource-group $RG_NAME \
    --name natgateway \
    --public-ip-addresses natgateway-ip \
    --idle-timeout 10

# Associate NAT gateway with subnet (assuming default subnet name)
az network vnet subnet update \
    --resource-group $RG_NAME \
    --vnet-name kubeadm \
    --name kubeadm-gw \
    --nat-gateway natgateway