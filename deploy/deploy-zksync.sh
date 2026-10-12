#!/bin/zsh

set -e # exit on error

# Source the .env file to load the variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

rpc_url="$ZKSYNC_RPC_URL"
if [ -z "$rpc_url" ]; then
    echo "ZKSYNC_RPC_URL not set"
    exit 1
fi
echo "RPC URL: $rpc_url"

keystore="$HOME/.foundry/keystores/$1"
echo "Keystore: $keystore"
if [ -e "$keystore" ]; then
    echo "Keystore provided"
else
    echo "Keystore not provided"
    exit 1
fi

forge script deploy/DeployEscrowFactoryZkSync.s.sol --zksync --fork-url $rpc_url --keystore $keystore --broadcast -vvvv
