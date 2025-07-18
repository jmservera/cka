#!/bin/bash

LB_NAME=${LB_NAME:-"kubeadm-lb"}
MASTER_COUNT=${MASTER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-2}
ADDRESS_PREFIX=${ADDRESS_PREFIX:-"10.224.0.0/12"}
SUBNET_PREFIX=${SUBNET_PREFIX:-"10.224.0.0/16"}

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

STEP=$1

if [ -z "$STEP" ]; then    
    # Call the network setup script
    echo "Setting up network infrastructure..."
    source ./scripts/01-network.sh    
    STEP=1
fi

if [ "$STEP" -le 2 ]; then
    # Call the VMs setup script
    echo "Setting up virtual machines..."
    source ./scripts/02-vms.sh
fi

# Call the additional NICs setup script
echo "Setting up additional NICs..."
source ./scripts/03-addips.sh

