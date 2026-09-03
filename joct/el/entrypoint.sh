#!/bin/sh
set -e

# JOC testnet: chainId is 10081 but the geth network id is 361257328 (per official docs)
NETWORKID=361257328
# Official bootnodes from japanopenchain.org docs (verified current as of Dec 2025) — override via BOOTNODES in .env
DEFAULT_BOOTNODES="enode://c68340e7daac1eecc3cdfbfc7c68a80ebf91dbc7f63413dae39b75b2738e63965033cefe452f0b50d8f1d2c5df74eba9905e85c223dda9bc0040fb1c06f35dc5@13.158.174.185:30303,enode://f964f94067a851758a3f308831602ca05a374a8a5dcba8ec5f78cde5d31dc809fc0115a84a785bbd1c8024a46d16eee732f4b681cc36cf323e8fab933f92849a@54.248.244.225:30303"

DATADIR=/data
GENESIS=/genesis.json
JWTSECRET=/data/jwtsecret

mkdir -p "$DATADIR"

# Shared secret that authenticates the Engine API (authrpc) call between geth and
# lighthouse. Generated once here; cl/entrypoint.sh reads it read-only from ../el/data
# (mounted at /jwt in the lighthouse container) and just waits for the file.
# Uses od/tr (busybox-safe) instead of openssl, which the geth image doesn't ship.
if [ ! -s "$JWTSECRET" ]; then
  echo "[geth] Generating JWT secret at $JWTSECRET..."
  head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$JWTSECRET"
  chmod 644 "$JWTSECRET"
fi

if [ ! -d "$DATADIR/geth/chaindata" ]; then
  echo "[testnet] Initializing datadir from $GENESIS..."
  geth init --datadir "$DATADIR" "$GENESIS"
fi

exec geth \
  --datadir "$DATADIR" \
  --networkid "$NETWORKID" \
  --bootnodes "${BOOTNODES:-$DEFAULT_BOOTNODES}" \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api "${HTTP_APIS:-eth,net,web3,txpool}" \
  --http.vhosts '*' \
  --http.corsdomain '*' \
  --authrpc.addr 0.0.0.0 \
  --authrpc.port 8551 \
  --authrpc.vhosts '*' \
  --authrpc.jwtsecret "$JWTSECRET" \
  "$@"
