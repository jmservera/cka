#!/bin/bash

for i in $(seq 1 5); do
    echo "Adding storage to worker VM $i..."
    sudo mkdir -p /media/k8s/0${i}
done
sudo chown -R azureuser:azureuser /media/k8s
