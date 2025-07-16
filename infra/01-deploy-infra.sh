#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Call the network setup script
echo "Setting up network infrastructure..."
source ./scripts/01-network.sh

# Call the VMs setup script
echo "Setting up virtual machines..."
source ./scripts/02-vms.sh