#!/bin/bash

set -euo pipefail

for i in $(seq 1 $MASTER_COUNT); do
    az vm create -n kube-master-$i -g $RG_NAME \
    --image $VMIMAGE \
    --vnet-name kubeadm --subnet kube \
    --admin-username azureuser \
    --ssh-key-value @~/.ssh/id_rsa.pub \
    --size $VMSIZE \
    --nsg kubeadm \
    --public-ip-sku Standard --no-wait
done

for i in $(seq 1 $WORKER_COUNT); do
    az vm create -n kube-worker-$i -g $RG_NAME \
    --image $VMIMAGE \
    --vnet-name kubeadm --subnet kube \
    --admin-username azureuser \
    --ssh-key-value @~/.ssh/id_rsa.pub \
    --size $VMSIZE \
    --nsg kubeadm \
    --public-ip-sku Standard --no-wait
done

echo "Waiting for master VMs to be created..."
for i in $(seq 1 $MASTER_COUNT); do
    az vm wait --created --name kube-master-$i -g $RG_NAME
done
echo "All master VMs created successfully"

for i in $(seq 1 $MASTER_COUNT); do
    az network nic ip-config address-pool add \
        --address-pool masternodes \
        --ip-config-name ipconfigkube-master-$i \
        --nic-name kube-master-${i}VMNic \
        --resource-group $RG_NAME \
        --lb-name kubemaster
done