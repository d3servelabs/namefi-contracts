#!/usr/bin/env bash
# check_create2_eligibility.sh
#
# Given a contract address on a source chain, confirms it was deployed via CREATE2
# and identifies the factory used.
#
# Usage:
#   ./check_create2_eligibility.sh --address <CONTRACT> --rpc <RPC_URL> --api-url <ETHERSCAN_API> --api-key <KEY>
#
# Outputs JSON with: factory, creation_tx, deployment_type (direct|indirect)

set -euo pipefail

# Parse arguments
ADDRESS=""
RPC=""
API_URL=""
API_KEY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --address) ADDRESS="$2"; shift 2 ;;
    --rpc) RPC="$2"; shift 2 ;;
    --api-url) API_URL="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ADDRESS" || -z "$RPC" ]]; then
  echo "Usage: $0 --address <CONTRACT> --rpc <RPC_URL> [--api-url <ETHERSCAN_API> --api-key <KEY>]" >&2
  exit 1
fi

# Known CREATE2 factories
NICK_DEPLOYER="0x4e59b44847b379578588920ca78fbf26c0b4956c"
OAGE_DEPLOYER="0x0000000000ffe8b47b3e2130213b802212439497"
SAFE_FACTORY="0x914d7fec6aac8cd542e72bca78b30650d45643d7"

echo "=== CREATE2 Eligibility Check ===" >&2
echo "Contract: $ADDRESS" >&2
echo "RPC: $RPC" >&2

# Step 1: Verify contract exists
CODE=$(cast code "$ADDRESS" --rpc-url "$RPC" 2>/dev/null || echo "0x")
if [[ "$CODE" == "0x" || -z "$CODE" ]]; then
  echo "ERROR: No code at $ADDRESS on this chain" >&2
  exit 1
fi
echo "Contract exists (code length: $((${#CODE} / 2 - 1)) bytes)" >&2

# Step 2: Get creation tx via Etherscan API (if available)
CREATION_TX=""
CREATOR=""
if [[ -n "$API_URL" && -n "$API_KEY" ]]; then
  echo "Querying explorer API for creation tx..." >&2
  RESULT=$(curl -s "${API_URL}?module=contract&action=getcontractcreation&contractaddresses=${ADDRESS}&apikey=${API_KEY}")
  CREATION_TX=$(echo "$RESULT" | jq -r '.result[0].txHash // empty' 2>/dev/null || echo "")
  CREATOR=$(echo "$RESULT" | jq -r '.result[0].contractCreator // empty' 2>/dev/null || echo "")
fi

if [[ -z "$CREATION_TX" ]]; then
  echo "Could not find creation tx via API. Please provide it manually." >&2
  echo '{"status": "manual_required", "address": "'"$ADDRESS"'", "message": "Provide creation tx hash"}'
  exit 0
fi

echo "Creation TX: $CREATION_TX" >&2
echo "Creator: $CREATOR" >&2

# Step 3: Get the creation tx details
TX_TO=$(cast tx "$CREATION_TX" to --rpc-url "$RPC" 2>/dev/null || echo "")
TX_TO_LOWER=$(echo "$TX_TO" | tr '[:upper:]' '[:lower:]')

# Step 4: Check if TO matches a known factory
FACTORY=""
DEPLOYMENT_TYPE=""

if [[ "$TX_TO_LOWER" == "$NICK_DEPLOYER" ]]; then
  FACTORY="$NICK_DEPLOYER"
  DEPLOYMENT_TYPE="direct"
  echo "Direct deployment via Nick's Deterministic Deployer" >&2
elif [[ "$TX_TO_LOWER" == "$OAGE_DEPLOYER" ]]; then
  FACTORY="$OAGE_DEPLOYER"
  DEPLOYMENT_TYPE="direct"
  echo "Direct deployment via 0age's CREATE2 Deployer" >&2
elif [[ "$TX_TO_LOWER" == "$SAFE_FACTORY" ]]; then
  FACTORY="$SAFE_FACTORY"
  DEPLOYMENT_TYPE="direct"
  echo "Direct deployment via Safe Singleton Factory" >&2
elif [[ -z "$TX_TO" || "$TX_TO" == "null" ]]; then
  echo "ERROR: This is a standard CREATE deployment (to=null). Cannot replicate via CREATE2." >&2
  echo '{"status": "not_create2", "address": "'"$ADDRESS"'", "creation_tx": "'"$CREATION_TX"'", "message": "Standard CREATE deployment"}'
  exit 0
else
  echo "TX to=$TX_TO is not a known factory. Checking internal transactions..." >&2
  DEPLOYMENT_TYPE="indirect"

  # Try to trace the tx for internal calls to known factories
  TRACE=$(cast run "$CREATION_TX" --rpc-url "$RPC" --trace 2>/dev/null || echo "")

  if echo "$TRACE" | grep -qi "$NICK_DEPLOYER"; then
    FACTORY="$NICK_DEPLOYER"
    echo "Found internal call to Nick's Deployer (indirect via $TX_TO)" >&2
  elif echo "$TRACE" | grep -qi "${OAGE_DEPLOYER:2}"; then
    FACTORY="$OAGE_DEPLOYER"
    echo "Found internal call to 0age's Deployer (indirect via $TX_TO)" >&2
  elif echo "$TRACE" | grep -qi "${SAFE_FACTORY:2}"; then
    FACTORY="$SAFE_FACTORY"
    echo "Found internal call to Safe Factory (indirect via $TX_TO)" >&2
  else
    echo "WARNING: No known CREATE2 factory found in internal transactions." >&2
    echo "The contract may use a custom factory or standard CREATE." >&2
    echo '{"status": "unknown", "address": "'"$ADDRESS"'", "creation_tx": "'"$CREATION_TX"'", "tx_to": "'"$TX_TO"'", "message": "Unknown deployment method"}'
    exit 0
  fi
fi

# Output result
cat <<EOF
{
  "status": "create2_confirmed",
  "address": "$ADDRESS",
  "creation_tx": "$CREATION_TX",
  "factory": "$FACTORY",
  "deployment_type": "$DEPLOYMENT_TYPE",
  "intermediary": $(if [[ "$DEPLOYMENT_TYPE" == "indirect" ]]; then echo "\"$TX_TO\""; else echo "null"; fi)
}
EOF
