#!/bin/zsh

set -e # exit on error

# Source the .env file to load the variables
if [ -f .env.deployment ]; then
    source .env.deployment
else
    echo -e "${EC}Error: .env.deployment file not found${NC}"
    exit 1
fi

# Define the chain configurations
typeset -A chains
chains["mainnet"]="$MAINNET_RPC_URL"
chains["bsc"]="$BSC_RPC_URL"
chains["polygon"]="$POLYGON_RPC_URL"
chains["avalanche"]="$AVALANCHE_RPC_URL"
chains["gnosis"]="$GNOSIS_RPC_URL"
chains["arbitrum"]="$ARBITRUM_RPC_URL"
chains["optimism"]="$OPTIMISM_RPC_URL"
chains["base"]="$BASE_RPC_URL"

rpc_url="${chains["$1"]}"
if [ -z "$rpc_url" ]; then
    echo "Chain not found"
    exit 1
fi
echo "Provided chain: $1"
echo "RPC URL: $rpc_url"

keystore="$HOME/.foundry-keystores/$2"
echo "Keystore: $keystore"
if [ -e "$keystore" ]; then
    echo "Keystore provided"
else
    echo "Keystore not provided"
    exit 1
fi

forge script script/DeployEscrowFactory.s.sol --fork-url $rpc_url --keystore $keystore --broadcast -vvvv
