#!/bin/zsh

source .env

CURRENT_DIR=$(dirname "$0")
CONFIG_PATH="${CURRENT_DIR}/../config/config.json"
SCRIPT_PATH="${CURRENT_DIR}/../onchain/CreateOrder.s.sol:CreateOrder"

# Read config values
if [[ -z "$CHAIN_ID" ]]; then
  CHAIN_ID=31337
fi

# Timelocks
WITHDRAWAL_SRC_TIMELOCK=$(jq -r '.withdrawalSrcTimelock' "$CONFIG_PATH")
WITHDRAWAL_DST_TIMELOCK=$(jq -r '.withdrawalDstTimelock' "$CONFIG_PATH")
CANCELLATION_SRC_TIMELOCK=$(jq -r '.cancellationSrcTimelock' "$CONFIG_PATH")
CANCELLATION_DST_TIMELOCK=$(jq -r '.cancellationDstTimelock' "$CONFIG_PATH")

echo -n "Do you want to rebuild project? Otherwise it will rebuild automatically if necessary [y/n]: "
read response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    forge clean
    forge build
fi

# Start anvil if local
if [[ "$CHAIN_ID" == "31337" ]]; then
  echo "Launching anvil with fork from $RPC_URL and block-time 1..."
  anvil --fork-url "$RPC_URL" --block-time 1 --chain-id 31337 --steps-tracing --host 127.0.0.1 --port 8545 -vvvvv > anvil.log 2>&1 &
  ANVIL_PID=$!
  sleep 15
  # Get anvil start timestamp
  ANVIL_START_TIMESTAMP=$(cast block latest --rpc-url http://localhost:8545 | grep timestamp | awk '{print $2}')
  echo "Anvil start timestamp: $ANVIL_START_TIMESTAMP"
  RPC_URL="http://localhost:8545"
fi

# Read stages array from config.json
STAGES=($(jq -r '.stages[]' "$CONFIG_PATH"))

ANVIL_DEPLOY_SRC_TIMESTAMP=$ANVIL_START_TIMESTAMP
ANVIL_DEPLOY_DST_TIMESTAMP=$ANVIL_START_TIMESTAMP
TIME_DELTA=5  # Time delta in seconds

for STAGE in "${STAGES[@]}"; do
    # Set next block timestamp for time-dependent stages
    if [[ "$CHAIN_ID" == "31337" ]]; then
        case "$STAGE" in
        withdrawSrc)
            NEXT_TS=$((ANVIL_DEPLOY_SRC_TIMESTAMP + WITHDRAWAL_SRC_TIMELOCK + TIME_DELTA))
            echo "Setting next block timestamp for withdrawSrc: $NEXT_TS"
            cast rpc anvil_setNextBlockTimestamp "$NEXT_TS" --rpc-url "$RPC_URL"
            ;;
        withdrawDst)
            NEXT_TS=$((ANVIL_DEPLOY_DST_TIMESTAMP + WITHDRAWAL_DST_TIMELOCK + TIME_DELTA))
            echo "Setting next block timestamp for withdrawDst: $NEXT_TS"
            cast rpc anvil_setNextBlockTimestamp "$NEXT_TS" --rpc-url "$RPC_URL"
            ;;
        cancelSrc)
            NEXT_TS=$((ANVIL_DEPLOY_SRC_TIMESTAMP + CANCELLATION_SRC_TIMELOCK + TIME_DELTA))
            echo "Setting next block timestamp for cancelSrc: $NEXT_TS"
            cast rpc anvil_setNextBlockTimestamp "$NEXT_TS" --rpc-url "$RPC_URL"
            ;;
        cancelDst)
            NEXT_TS=$((ANVIL_DEPLOY_DST_TIMESTAMP + CANCELLATION_DST_TIMELOCK + TIME_DELTA))
            echo "Setting next block timestamp for cancelDst: $NEXT_TS"
            cast rpc anvil_setNextBlockTimestamp "$NEXT_TS" --rpc-url "$RPC_URL"
            ;;
        esac
    fi

    echo "=== Running stage: $STAGE ==="
    MODE=$STAGE forge script "$SCRIPT_PATH" --broadcast --rpc-url "$RPC_URL"

    case "$STAGE" in
        deployEscrowSrc)
            ANVIL_DEPLOY_SRC_TIMESTAMP=$(cast block latest --rpc-url "$RPC_URL" | grep timestamp | awk '{print $2}')
            echo "New anvil deploy src timestamp: $ANVIL_DEPLOY_SRC_TIMESTAMP"
            ;;
        deployEscrowDst)
            ANVIL_DEPLOY_DST_TIMESTAMP=$(cast block latest --rpc-url "$RPC_URL" | grep timestamp | awk '{print $2}')
            echo "New anvil deploy dst timestamp: $ANVIL_DEPLOY_DST_TIMESTAMP"
            ;;
    esac

    echo -n "Continue to the next stage? [y/n]:" 
    read answer
    if [[ "$answer" == "n" || "$answer" == "N" ]]; then
        echo "Exiting script."
        break
    fi

    sleep 1
done

# Cleanup
if [[ "$CHAIN_ID" == "31337" ]]; then
    echo -n "Cleanup anvil instance? [y/n]:" 
    read answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo "Killing anvil..."
        kill $ANVIL_PID
    else
        echo "Don't forget to kill anvil manually by running 'kill $ANVIL_PID' if you want to stop it."
    fi
fi

echo "=== All stages completed ==="