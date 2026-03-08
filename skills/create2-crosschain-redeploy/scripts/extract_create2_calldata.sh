#!/usr/bin/env bash
# extract_create2_calldata.sh
#
# Extracts the raw CREATE2 calldata (salt + initCode) from a creation transaction.
# Handles both direct factory calls and Safe-wrapped (indirect) transactions.
#
# Usage:
#   ./extract_create2_calldata.sh --tx-hash <TX_HASH> --rpc <RPC_URL> [--trace] [--factory <FACTORY>]
#
# Outputs JSON with: salt, initCode, initCodeHash, expectedAddress

set -euo pipefail

TX_HASH=""
RPC=""
TRACE=false
FACTORY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tx-hash) TX_HASH="$2"; shift 2 ;;
    --rpc) RPC="$2"; shift 2 ;;
    --trace) TRACE=true; shift ;;
    --factory) FACTORY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TX_HASH" || -z "$RPC" ]]; then
  echo "Usage: $0 --tx-hash <TX_HASH> --rpc <RPC_URL> [--trace] [--factory <FACTORY>]" >&2
  exit 1
fi

NICK_DEPLOYER="0x4e59b44847b379578588920ca78fbf26c0b4956c"

echo "=== Extract CREATE2 Calldata ===" >&2
echo "TX: $TX_HASH" >&2

# Get the raw calldata
CALLDATA=$(cast tx "$TX_HASH" input --rpc-url "$RPC")
TX_TO=$(cast tx "$TX_HASH" to --rpc-url "$RPC")
TX_TO_LOWER=$(echo "$TX_TO" | tr '[:upper:]' '[:lower:]')

if [[ -z "$FACTORY" ]]; then
  FACTORY="$NICK_DEPLOYER"
fi

FACTORY_CALLDATA=""

if [[ "$TX_TO_LOWER" == "$(echo "$FACTORY" | tr '[:upper:]' '[:lower:]')" ]]; then
  # Direct call to factory
  echo "Direct factory call detected" >&2
  FACTORY_CALLDATA="$CALLDATA"
elif [[ "$TRACE" == true ]]; then
  # Need to trace for internal calls
  echo "Tracing transaction for internal calls to factory..." >&2

  # Use cast to get internal transactions
  # Try debug_traceTransaction first
  TRACE_RESULT=$(cast rpc debug_traceTransaction "$TX_HASH" '{"tracer": "callTracer"}' --rpc-url "$RPC" 2>/dev/null || echo "")

  if [[ -n "$TRACE_RESULT" && "$TRACE_RESULT" != "null" ]]; then
    # Parse the trace to find the call to the factory
    # Look for calls where 'to' matches the factory
    FACTORY_LOWER=$(echo "$FACTORY" | tr '[:upper:]' '[:lower:]')
    FACTORY_CALLDATA=$(echo "$TRACE_RESULT" | jq -r '
      .. | objects | select(.to? // "" | ascii_downcase == "'"$FACTORY_LOWER"'") | .input // empty
    ' 2>/dev/null | head -1)

    if [[ -n "$FACTORY_CALLDATA" ]]; then
      echo "Found factory call in trace" >&2
    else
      echo "WARNING: Factory call not found in trace. Trying alternative trace format..." >&2
      # Try finding in nested calls
      FACTORY_CALLDATA=$(echo "$TRACE_RESULT" | jq -r '
        .calls[]? | .. | objects | select(.to? // "" | ascii_downcase == "'"$FACTORY_LOWER"'") | .input // empty
      ' 2>/dev/null | head -1)
    fi
  fi

  if [[ -z "$FACTORY_CALLDATA" ]]; then
    echo "ERROR: Could not extract factory calldata from trace." >&2
    echo "Try manually inspecting the internal transactions on the block explorer." >&2
    exit 1
  fi
else
  echo "ERROR: TX to=$TX_TO is not the factory. Use --trace to extract from internal transactions." >&2
  exit 1
fi

# For Nick's deployer: calldata = salt (32 bytes = 64 hex chars) || initCode
# Remove 0x prefix
CALLDATA_HEX="${FACTORY_CALLDATA#0x}"

if [[ ${#CALLDATA_HEX} -lt 64 ]]; then
  echo "ERROR: Calldata too short to contain salt + initCode" >&2
  exit 1
fi

SALT="0x${CALLDATA_HEX:0:64}"
INIT_CODE="0x${CALLDATA_HEX:64}"

echo "Salt: $SALT" >&2
echo "InitCode length: $(( ${#CALLDATA_HEX} / 2 - 32 )) bytes" >&2

# Compute initCodeHash
INIT_CODE_HASH=$(cast keccak "$INIT_CODE")
echo "InitCode hash: $INIT_CODE_HASH" >&2

# Compute expected CREATE2 address
# CREATE2: keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
FACTORY_CLEAN="${FACTORY#0x}"
SALT_CLEAN="${SALT#0x}"
INIT_CODE_HASH_CLEAN="${INIT_CODE_HASH#0x}"

PREIMAGE="0xff${FACTORY_CLEAN}${SALT_CLEAN}${INIT_CODE_HASH_CLEAN}"
FULL_HASH=$(cast keccak "$PREIMAGE")
EXPECTED_ADDRESS="0x${FULL_HASH: -40}"

echo "Expected address: $EXPECTED_ADDRESS" >&2

# Output JSON
cat <<EOF
{
  "tx_hash": "$TX_HASH",
  "factory": "$FACTORY",
  "salt": "$SALT",
  "initCode": "$INIT_CODE",
  "initCodeHash": "$INIT_CODE_HASH",
  "expectedAddress": "$EXPECTED_ADDRESS",
  "calldataLength": $((${#CALLDATA_HEX} / 2))
}
EOF
