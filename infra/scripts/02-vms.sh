#!/bin/bash

LB_NAME=${LB_NAME:-"kubeadm-lb"}
MASTER_COUNT=${MASTER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-2}
SHUTDOWN_TIME=${SHUTDOWN_TIME:-"20:00"}

set -euo pipefail

for i in $(seq 1 $MASTER_COUNT); do
    az vm create -n kube-master-$i -g $RG_NAME \
    --image $VMIMAGE \
    --vnet-name kubeadm --subnet kube \
    --subnet-address-prefix $SUBNET_PREFIX \
    --admin-username azureuser \
    --ssh-key-value @~/.ssh/id_rsa.pub \
    --size $VMSIZE \
    --public-ip-address "" \
    --nsg kubeadm --no-wait
done

for i in $(seq 1 $WORKER_COUNT); do
    az vm create -n kube-worker-$i -g $RG_NAME \
    --image $VMIMAGE \
    --vnet-name kubeadm --subnet kube \
    --subnet-address-prefix $SUBNET_PREFIX \
    --admin-username azureuser \
    --ssh-key-value @~/.ssh/id_rsa.pub \
    --size $VMSIZE \
    --public-ip-address "" \
    --nsg kubeadm --no-wait
done

echo "Set auto-shutdown time for all VMs to $SHUTDOWN_TIME"

for i in $(seq 1 $MASTER_COUNT); do
    az vm wait --created --name kube-master-$i -g $RG_NAME
    az vm auto-shutdown -g $RG_NAME -n kube-master-$i --time $SHUTDOWN_TIME
done

for i in $(seq 1 $WORKER_COUNT); do
    az vm wait --created --name kube-worker-$i -g $RG_NAME
    az vm auto-shutdown -g $RG_NAME -n kube-worker-$i --time $SHUTDOWN_TIME
done