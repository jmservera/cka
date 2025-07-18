#!/bin/bash

LB_NAME=${LB_NAME:-"kubeadm-lb"}
MASTER_COUNT=${MASTER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-2}

echo "Update vNICs for master VMs..."
for i in $(seq 1 $MASTER_COUNT); do
    az network nic update \
        --resource-group $RG_NAME \
        --name kube-master-${i}VMNic \
        --ip-forwarding true
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

echo "Update vNICs for worker VMs..."
for i in $(seq 1 $WORKER_COUNT); do

    # update nic for enabling ip-fowarding
    az network nic update \
        --resource-group $RG_NAME \
        --name kube-worker-${i}VMNic \
        --ip-forwarding true        

    # add 10 private IPs to each node VM
    echo "Adding additional NICs to kube-worker-$i..."
    for j in $(seq 1 10); do
        echo -n "$j"
        az network nic ip-config create \
            --name ipconfigkube-worker-$i-$j \
            --vnet-name kubeadm \
            --nic-name kube-worker-${i}VMNic \
            --resource-group $RG_NAME \
            --subnet kube \
            --no-wait
    done
    echo " done"
done
echo "All worker VMs created successfully"

echo "Adding master VMs to the load balancer..."
for i in $(seq 1 $MASTER_COUNT); do
    az network nic ip-config address-pool add \
        --address-pool masternodes \
        --ip-config-name ipconfigkube-master-$i \
        --nic-name kube-master-${i}VMNic \
        --resource-group $RG_NAME \
        --lb-name $LB_NAME 
done

# echo "Adding worker VMs to the load balancer..."
# for i in $(seq 1 $WORKER_COUNT); do
#     az network nic ip-config address-pool add \
#         --address-pool workernodes \
#         --ip-config-name ipconfigkube-worker-$i \
#         --nic-name kube-worker-${i}VMNic \
#         --resource-group $RG_NAME \
#         --lb-name $LB_NAME 
# done