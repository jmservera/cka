#!/bin/bash

cd /media
sudo mkdir k8s
sudo chown azureuser:azureuser k8s
for i in $(seq 1 5); do
    echo "Adding storage to master VM $i..."
    mkdir k8s/0${i}
done