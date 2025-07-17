#!/bin/bash

set -euo pipefail

# Check if RG_NAME is set
if [ -z "${RG_NAME:-}" ]; then
    echo "Error: RG_NAME environment variable is not set"
    exit 1
fi

# Check if MASTER_COUNT is set
if [ -z "${MASTER_COUNT:-}" ]; then
    echo "Error: MASTER_COUNT environment variable is not set"
    exit 1
fi

# Validate MASTER_COUNT is a positive integer
if ! [[ "$MASTER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: MASTER_COUNT must be a positive integer"
    exit 1
fi

az network vnet create \
    -g $RG_NAME \
    --name kubeadm \
    --address-prefix 10.224.0.0/12 \
    --subnet-name kube \
    --subnet-prefix 192.224.0.0/16

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
    -g $RG_NAME \
    -n kube \
    --vnet-name kubeadm \
    --network-security-group kubeadm

az network public-ip create \
    --resource-group $RG_NAME \
    --name controlplaneip \
    --sku Standard \
    --dns-name $LB_NAME

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

# create outbound rule for NAT
az network lb outbound-rule create \
    --resource-group $RG_NAME \
    --lb-name kubemaster \
    --name kubemaster-outbound \
    --protocol All \
    --frontend-ip-name controlplaneip \
    --idle-timeout 15 \
    --enable-tcp-reset true \
    --backend-pool-name masternodes \
    --allocated-outbound-ports 1000 \
    --idle-timeout 10 \
    --snat-ports 1000

# # Create NAT gateway public IP //TODO use existing LB
# az network public-ip create \
#     --resource-group $RG_NAME \
#     --name natgateway-ip \
#     --sku Standard \
#     --allocation-method Static

# # Create NAT gateway
# az network nat gateway create \
#     --resource-group $RG_NAME \
#     --name natgateway \
#     --public-ip-addresses natgateway-ip \
#     --idle-timeout 10

# # Associate NAT gateway with subnet (assuming default subnet name)
# az network vnet subnet update \
#     --resource-group $RG_NAME \
#     --vnet-name kubeadm \
#     --name kubeadm-gw \
#     --nat-gateway natgateway

# az network vnet subnet update \
#     --resource-group $RG_NAME \
#     --vnet-name kubeadm \
#     --name kube \
#     --nat-gateway natgateway