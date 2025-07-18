#!/bin/bash

if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

MASTER_COUNT=${MASTER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-2}
ADDRESS_PREFIX=${ADDRESS_PREFIX:-"10.224.0.0/12"}
SUBNET_PREFIX=${SUBNET_PREFIX:-"10.224.0.0/16"}

for i in $(seq 1 $MASTER_COUNT); do
    (echo "Preparing master VM $i..."
    az vm run-command invoke \
        --resource-group $RG_NAME \
        --name kube-master-$i \
        --command-id RunShellScript \
        --scripts @scripts/04-prepare-vm.sh)&
done

for i in $(seq 1 $WORKER_COUNT); do
    (echo "Preparing worker VM $i..."
    az vm run-command invoke \
        --resource-group $RG_NAME \
        --name kube-worker-$i \
        --command-id RunShellScript \
        --scripts @scripts/04-prepare-vm.sh
    az vm run-command invoke \
        --resource-group $RG_NAME \
        --name kube-worker-$i \
        --command-id RunShellScript \
        --scripts @scripts/05-add-storage.sh)&
done