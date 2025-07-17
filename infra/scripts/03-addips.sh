#!/bin/bash

echo "Waiting for master VMs to be created..."
for i in $(seq 1 $MASTER_COUNT); do
    az vm wait --created --name kube-master-$i -g $RG_NAME
    # add 10 private IPs to each master VM
    echo "Adding additional NICs to kube-master-$i..."
    for j in $(seq 1 10); do
        echo -n "$j"
        az network nic ip-config create \
            --name ipconfigkube-master-$i-$j \
            --vnet-name kubeadm \
            --nic-name kube-master-${i}VMNic \
            --resource-group $RG_NAME \
            --subnet kube \
            --no-wait
    done
    echo " done"
done
echo "All master VMs created successfully"

echo "Waiting for worker VMs to be created..."
for i in $(seq 1 $WORKER_COUNT); do
    az vm wait --created --name kube-worker-$i -g $RG_NAME
    # add 10 private IPs to each node VM
    echo "Adding additional NICs to kube-worker-$i..."
    for j in $(seq 1 10); do
        echo -n "$j"
        az network nic ip-config create \
            --name ipconfigkube-master-$i-$j \
            --vnet-name kubeadm \
            --nic-name kube-master-${i}VMNic \
            --resource-group $RG_NAME \
            --subnet kube \
            --no-wait
    done
    echo " done"
done
echo "All worker VMs created successfully"


echo "Creating and assigning public IP to kube-master-1..."
az network public-ip create \
    --name kube-master-1-pip \
    --resource-group $RG_NAME \
    --allocation-method Static \
    --sku Standard

az network nic ip-config update \
    --name ipconfigkube-master-1 \
    --nic-name kube-master-1VMNic \
    --resource-group $RG_NAME \
    --public-ip-address kube-master-1-pip

for i in $(seq 1 $MASTER_COUNT); do
    az network nic ip-config address-pool add \
        --address-pool masternodes \
        --ip-config-name ipconfigkube-master-$i \
        --nic-name kube-master-${i}VMNic \
        --resource-group $RG_NAME \
        --lb-name kubemaster
done