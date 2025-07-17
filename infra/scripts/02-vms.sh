#!/bin/bash

set -euo pipefail

for i in $(seq 1 $MASTER_COUNT); do
    az vm create -n kube-master-$i -g $RG_NAME \
    --image $VMIMAGE \
    --vnet-name kubeadm --subnet kube \
    --admin-username azureuser \
    --ssh-key-value @~/.ssh/id_rsa.pub \
    --size $VMSIZE \
    --nsg kubeadm --no-wait
done

for i in $(seq 1 $WORKER_COUNT); do
    az vm create -n kube-worker-$i -g $RG_NAME \
    --image $VMIMAGE \
    --vnet-name kubeadm --subnet kube \
    --admin-username azureuser \
    --ssh-key-value @~/.ssh/id_rsa.pub \
    --size $VMSIZE \
    --nsg kubeadm --no-wait
done

