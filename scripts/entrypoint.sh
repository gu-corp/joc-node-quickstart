#!/bin/sh
set -e

NETWORK=${NETWORK:-mainnet}

# Official bootnodes from japanopenchain.org docs (Dec 2024) — override via BOOTNODES in .env
case "$NETWORK" in
  mainnet)
    NETWORKID=81
    DEFAULT_BOOTNODES="enode://c387e2b4e5231022ef30144c41fbd883139e9b5f1f4649c3d51c1611adbfaeadfd050c1bd9ac02eec6fa4c234b49a77fb5fb54f739c06d431eabfd981edc51f2@13.56.117.179:30303,enode://db803c26db9dac21e58452646a785b94a466eebffd6038621f78de92ccc6141fcb297650c290487375ab32a6dbc693d5dab49dba9785450002c68944ab0435a2@54.241.98.152:30303"
    ;;
  testnet)
    # JOC testnet: chainId is 10081 but the geth network id is 361257328 (per official docs)
    NETWORKID=361257328
    DEFAULT_BOOTNODES="enode://c68340e7daac1eecc3cdfbfc7c68a80ebf91dbc7f63413dae39b75b2738e63965033cefe452f0b50d8f1d2c5df74eba9905e85c223dda9bc0040fb1c06f35dc5@13.158.174.185:30303,enode://f964f94067a851758a3f308831602ca05a374a8a5dcba8ec5f78cde5d31dc809fc0115a84a785bbd1c8024a46d16eee732f4b681cc36cf323e8fab933f92849a@54.248.244.225:30303"
    ;;
  *)
    echo "Unknown NETWORK '$NETWORK' (expected: mainnet | testnet)" >&2
    exit 1
    ;;
esac

DATADIR=/data/$NETWORK
GENESIS=/genesis/${NETWORK}_genesis.json

if [ ! -d "$DATADIR/geth/chaindata" ]; then
  echo "[$NETWORK] Initializing datadir from $GENESIS..."
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
