#!/bin/bash

LB_NAME=${LB_NAME:-"kubeadm-lb"}
MASTER_COUNT=${MASTER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-2}
ADDRESS_PREFIX=${ADDRESS_PREFIX:-"10.224.0.0/12"}
SUBNET_PREFIX=${SUBNET_PREFIX:-"10.224.0.0/16"}

set -euo pipefail

# Check if RG_NAME is set
if [ -z "${RG_NAME:-}" ]; then
    echo "Error: RG_NAME environment variable is not set"
    exit 1
fi



# Validate MASTER_COUNT is a positive integer
if ! [[ "$MASTER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: MASTER_COUNT must be a positive integer"
    exit 1
fi

# Validate MASTER_COUNT is a positive integer
if ! [[ "$WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: WORKER_COUNT must be a positive integer"
    exit 1
fi

az network vnet create \
    -g $RG_NAME \
    --name kubeadm \
    --address-prefix $ADDRESS_PREFIX \
    --subnet-name kube \
    --subnet-prefix $SUBNET_PREFIX

az network nsg create \
    -g $RG_NAME \
    --name kubeadm

# Kubernetes API server port
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
    --name $LB_NAME \
    --sku Standard \
    --public-ip-address controlplaneip \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes     

az network lb probe create \
    --resource-group $RG_NAME \
    --lb-name $LB_NAME \
    --name ${LB_NAME}_web \
    --protocol tcp \
    --port 6443   

az network lb rule create \
    --resource-group $RG_NAME \
    --lb-name $LB_NAME \
    --name $LB_NAME \
    --protocol tcp \
    --frontend-port 6443 \
    --backend-port 6443 \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes \
    --probe-name ${LB_NAME}_web \
    --disable-outbound-snat true \
    --idle-timeout 15 \
    --enable-tcp-reset true

# create outbound rule for NAT
# az network lb outbound-rule create \
#     --resource-group $RG_NAME \
#     --lb-name $LB_NAME \
#     --name kubemaster-outbound \
#     --protocol All \
#     --frontend-ip-configs controlplaneip \
#     --idle-timeout 15 \
#     --enable-tcp-reset true \
#     --address-pool masternodes \
#     --allocated-outbound-ports 1000

# create workers outbound rule for NAT
# az network public-ip create \
#     --resource-group $RG_NAME \
#     --name nodeoutboundip \
#     --sku Standard \
#     --dns-name ${LB_NAME}nodes

# az network lb address-pool create \
#     --resource-group $RG_NAME \
#     --lb-name $LB_NAME \
#     --name workernodes

# az network lb frontend-ip create \
#     --resource-group $RG_NAME \
#     --lb-name $LB_NAME \
#     --name nodeoutboundip \
#     --public-ip-address nodeoutboundip

# az network lb outbound-rule create \
#     --resource-group $RG_NAME \
#     --lb-name $LB_NAME \
#     --name node-outbound \
#     --protocol All \
#     --frontend-ip-configs nodeoutboundip \
#     --idle-timeout 4 \
#     --enable-tcp-reset true \
#     --address-pool workernodes \
#     --allocated-outbound-ports 320


# Inbound nat for SSH to master nodes
az network lb inbound-nat-rule create \
    -g $RG_NAME \
    --lb-name $LB_NAME \
    -n ssh_master \
    --protocol Tcp \
    --frontend-port-range-start 22 \
    --frontend-port-range-end 32 \
    --backend-port 22 \
    --backend-address-pool masternodes \
    --frontend-ip-name controlplaneip \
    --enable-tcp-reset true \
    --idle-timeout 15

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
    --name kube \
    --nat-gateway natgateway

