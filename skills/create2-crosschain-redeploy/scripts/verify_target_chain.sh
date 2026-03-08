#!/usr/bin/env bash
# verify_target_chain.sh
#
# Checks that the CREATE2 factory and necessary infrastructure exist on the target chain.
# Also verifies that the target addresses are empty (no existing deployment).
#
# Usage:
#   ./verify_target_chain.sh --factory <FACTORY> --rpc <TARGET_RPC> [--addresses <ADDR1,ADDR2,...>]

set -euo pipefail

FACTORY=""
RPC=""
ADDRESSES=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --factory) FACTORY="$2"; shift 2 ;;
    --rpc) RPC="$2"; shift 2 ;;
    --addresses) ADDRESSES="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$FACTORY" || -z "$RPC" ]]; then
  echo "Usage: $0 --factory <FACTORY> --rpc <TARGET_RPC> [--addresses <ADDR1,ADDR2,...>]" >&2
  exit 1
fi

NICK_DEPLOYER="0x4e59b44847b379578588920ca78fbf26c0b4956c"
MULTICALL3="0xcA11bde05977b3631167028862bE2a173976CA11"

echo "=== Target Chain Verification ===" >&2
echo "RPC: $RPC" >&2

# Check chain ID
CHAIN_ID=$(cast chain-id --rpc-url "$RPC" 2>/dev/null || echo "unknown")
echo "Chain ID: $CHAIN_ID" >&2

# Check factory
echo "" >&2
echo "--- Factory Check ---" >&2
FACTORY_CODE=$(cast code "$FACTORY" --rpc-url "$RPC" 2>/dev/null || echo "0x")
FACTORY_EXISTS=false
if [[ "$FACTORY_CODE" != "0x" && -n "$FACTORY_CODE" ]]; then
  FACTORY_EXISTS=true
  echo "Factory $FACTORY: EXISTS" >&2
else
  echo "Factory $FACTORY: NOT FOUND" >&2
  if [[ "$(echo "$FACTORY" | tr '[:upper:]' '[:lower:]')" == "$NICK_DEPLOYER" ]]; then
    echo "  -> Nick's deployer can be deployed using its pre-signed tx" >&2
    echo "  -> See references/known-factories.md for deployment instructions" >&2
  fi
fi

# Check Multicall3 (useful for batched deployments)
echo "" >&2
echo "--- Multicall3 Check ---" >&2
MC3_CODE=$(cast code "$MULTICALL3" --rpc-url "$RPC" 2>/dev/null || echo "0x")
MC3_EXISTS=false
if [[ "$MC3_CODE" != "0x" && -n "$MC3_CODE" ]]; then
  MC3_EXISTS=true
  echo "Multicall3: EXISTS" >&2
else
  echo "Multicall3: NOT FOUND (batched deployment unavailable)" >&2
fi

# Check target addresses are empty
ADDR_RESULTS="[]"
if [[ -n "$ADDRESSES" ]]; then
  echo "" >&2
  echo "--- Target Address Check ---" >&2
  ADDR_RESULTS="["
  FIRST=true
  IFS=',' read -ra ADDR_LIST <<< "$ADDRESSES"
  for ADDR in "${ADDR_LIST[@]}"; do
    ADDR=$(echo "$ADDR" | xargs) # trim whitespace
    CODE=$(cast code "$ADDR" --rpc-url "$RPC" 2>/dev/null || echo "0x")
    EMPTY=true
    if [[ "$CODE" != "0x" && -n "$CODE" ]]; then
      EMPTY=false
      echo "  $ADDR: HAS CODE (already deployed!)" >&2
    else
      echo "  $ADDR: EMPTY (ready for deployment)" >&2
    fi
    if [[ "$FIRST" != true ]]; then ADDR_RESULTS+=","; fi
    ADDR_RESULTS+="$(printf '{"address":"%s","empty":%s}' "$ADDR" "$EMPTY")"
    FIRST=false
  done
  ADDR_RESULTS+="]"
fi

# Check gas token balance of common deployer patterns
echo "" >&2
echo "--- Chain Info ---" >&2
LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo "unknown")
echo "Latest block: $LATEST_BLOCK" >&2

# Output JSON
cat <<EOF
{
  "chain_id": "$CHAIN_ID",
  "latest_block": "$LATEST_BLOCK",
  "factory": {
    "address": "$FACTORY",
    "exists": $FACTORY_EXISTS
  },
  "multicall3": {
    "address": "$MULTICALL3",
    "exists": $MC3_EXISTS
  },
  "target_addresses": $ADDR_RESULTS
}
EOF
