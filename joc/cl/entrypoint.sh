#!/bin/sh
set -e

# Official mainnet consensus bootnode ENRs from japan-open-chain/mainnet
# (metadata/bootstrap_nodes.yaml, liveness proven by its discv5_probe.py) —
# override via BOOT_ENRS in .env.
DEFAULT_BOOT_ENRS="enr:-IS4QCD8WwWL4D2aqhxck-Xe2oWmKOxX8MIfTSIbm8NUSO2cIl1-ajvVhI3qtIKYZCLWnIwUOctRuphmdsKsoEn_WXsBgmlkgnY0gmlwhDbHWLWJc2VjcDI1NmsxoQJ0qmTB_5PvfYu4xOKPPSdK_GDkeeKB30pII1nZBfTCSIN1ZHCCIyg,enr:-N24QEseGCZiwkxELcFEQbB1uXCztP9tbz06fuGwO0oMqRhHQJUlbAp7irqbsoj050k-eB9_ce5nu-yxxiJtoHgPQ9YDh2F0dG5ldHOIAAAAAAMAAACGY2xpZW500YpMaWdodGhvdXNlhTcuMC4xhGV0aDKQT9zM3gIAAFH__________4JpZIJ2NIJpcIQ2-PdmhHF1aWOCIymJc2VjcDI1NmsxoQI2lQsosw7dw7ssqdwQZ6U580ZG4Gtlqem1RTbH-LDgXIhzeW5jbmV0cwCDdGNwgiMog3VkcIIjKA"

DATADIR=/data
CONFIGDIR="$DATADIR/config"
JWTSECRET=/jwt/mainnet/jwtsecret

mkdir -p "$CONFIGDIR"
[ -f "$CONFIGDIR/config.yaml" ] || cp /config.yaml "$CONFIGDIR/config.yaml"
[ -f "$CONFIGDIR/genesis.ssz" ] || cp /genesis.ssz "$CONFIGDIR/genesis.ssz"
[ -f "$CONFIGDIR/deposit_contract_block.txt" ] || cp /deposit_contract_block.txt "$CONFIGDIR/deposit_contract_block.txt"

echo "[lighthouse] Waiting for JWT secret at $JWTSECRET (written by the joc-node container into ../el/data/mainnet)..."
while [ ! -s "$JWTSECRET" ]; do sleep 1; done

# No --checkpoint-sync-url: JOC hasn't published a public beacon RPC endpoint for
# mainnet yet (unlike testnet's rpc-1.testnet.japanopenchain.org:3500). Syncs from
# the real ./genesis.ssz instead — slower, but genesis.ssz here isn't a placeholder.
exec lighthouse beacon_node \
  --datadir "$DATADIR" \
  --testnet-dir "$CONFIGDIR" \
  --http \
  --http-address 0.0.0.0 \
  --http-port 5052 \
  --execution-endpoint http://joc-node:8551 \
  --execution-jwt "$JWTSECRET" \
  --boot-nodes "${BOOT_ENRS:-$DEFAULT_BOOT_ENRS}" \
  "$@"
