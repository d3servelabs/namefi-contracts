#!/usr/bin/env bash
# build_simulation_tx.sh
#
# Constructs a Tenderly-compatible simulation bundle from a deployment JSON spec.
# Outputs a JSON file that can be submitted to Tenderly's simulate API.
#
# Usage:
#   ./build_simulation_tx.sh --deployment-json <FILE> --target-rpc <RPC> --sender <ADDRESS> [--output <FILE>]
#
# The deployment JSON should contain an array of deployment steps:
# {
#   "chain_id": "46630",
#   "steps": [
#     {
#       "label": "Deploy NamefiNFT impl",
#       "to": "0x4e59b44847b379578588920ca78fbf26c0b4956c",
#       "data": "0x<salt><initCode>",
#       "value": "0",
#       "expectedAddress": "0x..."
#     },
#     ...
#   ]
# }

set -euo pipefail

DEPLOYMENT_JSON=""
TARGET_RPC=""
SENDER=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --deployment-json) DEPLOYMENT_JSON="$2"; shift 2 ;;
    --target-rpc) TARGET_RPC="$2"; shift 2 ;;
    --sender) SENDER="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$DEPLOYMENT_JSON" || -z "$TARGET_RPC" || -z "$SENDER" ]]; then
  echo "Usage: $0 --deployment-json <FILE> --target-rpc <RPC> --sender <ADDRESS> [--output <FILE>]" >&2
  exit 1
fi

if [[ ! -f "$DEPLOYMENT_JSON" ]]; then
  echo "ERROR: Deployment JSON file not found: $DEPLOYMENT_JSON" >&2
  exit 1
fi

echo "=== Build Simulation TX Bundle ===" >&2
echo "Deployment spec: $DEPLOYMENT_JSON" >&2
echo "Target RPC: $TARGET_RPC" >&2
echo "Sender: $SENDER" >&2

# Read chain ID from the deployment JSON
CHAIN_ID=$(jq -r '.chain_id' "$DEPLOYMENT_JSON")
echo "Chain ID: $CHAIN_ID" >&2

# Get the latest block for simulation context
BLOCK_NUMBER=$(cast block-number --rpc-url "$TARGET_RPC" 2>/dev/null || echo "latest")
echo "Block number: $BLOCK_NUMBER" >&2

# Build Tenderly simulation bundle
# Each step becomes a separate simulation transaction
STEPS=$(jq -c '.steps[]' "$DEPLOYMENT_JSON")
SIMULATIONS="["
FIRST=true
INDEX=0

while IFS= read -r STEP; do
  LABEL=$(echo "$STEP" | jq -r '.label')
  TO=$(echo "$STEP" | jq -r '.to')
  DATA=$(echo "$STEP" | jq -r '.data')
  VALUE=$(echo "$STEP" | jq -r '.value // "0"')
  EXPECTED=$(echo "$STEP" | jq -r '.expectedAddress // ""')
  GAS_LIMIT=$(echo "$STEP" | jq -r '.gasLimit // "10000000"')

  echo "  Step $INDEX: $LABEL" >&2
  if [[ -n "$EXPECTED" && "$EXPECTED" != "null" ]]; then
    echo "    Expected: $EXPECTED" >&2
  fi

  if [[ "$FIRST" != true ]]; then SIMULATIONS+=","; fi

  SIMULATIONS+=$(cat <<SIMEOF
{
    "network_id": "$CHAIN_ID",
    "block_number": $BLOCK_NUMBER,
    "from": "$SENDER",
    "to": "$TO",
    "input": "$DATA",
    "value": "$VALUE",
    "gas": $GAS_LIMIT,
    "save": true,
    "save_if_fails": true,
    "simulation_type": "full",
    "description": "$LABEL"$(if [[ -n "$EXPECTED" && "$EXPECTED" != "null" ]]; then echo ",
    \"expected_address\": \"$EXPECTED\""; fi)
  }
SIMEOF
)

  FIRST=false
  INDEX=$((INDEX + 1))
done <<< "$STEPS"

SIMULATIONS+="]"

# Wrap in Tenderly bundle format
BUNDLE=$(cat <<EOF
{
  "simulations": $SIMULATIONS
}
EOF
)

if [[ -n "$OUTPUT" ]]; then
  echo "$BUNDLE" | jq '.' > "$OUTPUT"
  echo "" >&2
  echo "Simulation bundle written to: $OUTPUT" >&2
  echo "Total steps: $INDEX" >&2
  echo "" >&2
  echo "To run via Hardhat fork simulation instead:" >&2
  echo "  npx hardhat run scripts/simulate-deploy.ts --network hardhat" >&2
else
  echo "$BUNDLE" | jq '.'
fi
