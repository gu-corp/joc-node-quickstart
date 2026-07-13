#!/bin/sh
set -e

# JOC mainnet: chain id 81, geth network id 81
NETWORKID=81
# Official bootnodes from japanopenchain.org docs (verified current as of Dec 2025) — override via BOOTNODES in .env
DEFAULT_BOOTNODES="enode://c387e2b4e5231022ef30144c41fbd883139e9b5f1f4649c3d51c1611adbfaeadfd050c1bd9ac02eec6fa4c234b49a77fb5fb54f739c06d431eabfd981edc51f2@13.56.117.179:30303,enode://db803c26db9dac21e58452646a785b94a466eebffd6038621f78de92ccc6141fcb297650c290487375ab32a6dbc693d5dab49dba9785450002c68944ab0435a2@54.241.98.152:30303"

DATADIR=/data/mainnet
GENESIS=/genesis.json

if [ ! -d "$DATADIR/geth/chaindata" ]; then
  echo "[mainnet] Initializing datadir from $GENESIS..."
  geth init --datadir "$DATADIR" "$GENESIS"
fi

exec geth \
  --datadir "$DATADIR" \
  --networkid "$NETWORKID" \
  --syncmode full \
  --gcmode full \
  --bootnodes "${BOOTNODES:-$DEFAULT_BOOTNODES}" \
  --port 30303 \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api "${HTTP_APIS:-eth,net,web3,txpool}" \
  --http.vhosts '*' \
  --http.corsdomain '*' \
  --ws \
  --ws.addr 0.0.0.0 \
  --ws.port 8546 \
  --ws.api "${WS_APIS:-eth,net,web3}" \
  --ws.origins '*' \
  "$@"
