#!/bin/sh
set -e

# Official testnet consensus bootnode ENRs from japanopenchain.org docs (same commit
# that added the Geth+Lighthouse testnet guide) — override via BOOT_ENRS in .env.
DEFAULT_BOOT_ENRS="enr:-IS4QG-lVIOC_Yun6wk_54ZOrps5tZmoZMFXLFc7wfB76COpDqfbTaODeXBYdXOpItPZt0W4a6Xo5_ugK9gsBV0FVIUBgmlkgnY0gmlwhBKx9kiJc2VjcDI1NmsxoQM5rT8o1LnjEKbXrhN9rznOJqkv2i0meNKMXDwODAKqtoN1ZHCCIyg,enr:-IS4QHDlPMfsFccuuDJkMSZVbj_QUlcl9bM7KMtEA3RQcNGadtJRfiyQeZERXjmLm17iztATiLd-Vbs8b-4fJHYmJhkBgmlkgnY0gmlwhDRFkJmJc2VjcDI1NmsxoQOxqYMNUWe2dvOG9yIuB0yMZQeRrFXsT_bAKU8OJFREq4N1ZHCCIyg"

DATADIR=/data
CONFIGDIR="$DATADIR/config"
JWTSECRET=/jwt/jwtsecret

mkdir -p "$CONFIGDIR"
[ -f "$CONFIGDIR/config.yaml" ] || cp /config.yaml "$CONFIGDIR/config.yaml"
[ -f "$CONFIGDIR/genesis.ssz" ] || cp /genesis.ssz "$CONFIGDIR/genesis.ssz"
[ -f "$CONFIGDIR/deposit_contract_block.txt" ] || cp /deposit_contract_block.txt "$CONFIGDIR/deposit_contract_block.txt"

echo "[lighthouse] Waiting for JWT secret at $JWTSECRET (written by the joct-node container into ../el/data)..."
while [ ! -s "$JWTSECRET" ]; do sleep 1; done

exec lighthouse beacon_node \
  --datadir "$DATADIR" \
  --testnet-dir "$CONFIGDIR" \
  --http \
  --http-address 0.0.0.0 \
  --http-port 5052 \
  --execution-endpoint http://joct-node:8551 \
  --execution-jwt "$JWTSECRET" \
  --boot-nodes "${BOOT_ENRS:-$DEFAULT_BOOT_ENRS}" \
  "$@"
