#!/bin/sh
echo "Setting up environment variables..."
azd env set CLIENT_IP_ADDRESS $(curl ifconfig.me 2>/dev/null | tr -d '\r')
if [ -z "$VSCODE_SERVER_TOKEN" ]; then
    azd env set VSCODE_SERVER_TOKEN $(uuidgen)
else
    echo "Using existing VSCODE_SERVER_TOKEN: $VSCODE_SERVER_TOKEN"
fi

azd env set AZURE_PUBLIC_KEY "$(cat ~/.ssh/id_rsa.pub)"