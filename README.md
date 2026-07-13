# joc-node-quickstart

Spin up a [Japan Open Chain](https://www.japanopenchain.org/en/docs/developer/connect-joc/mainnet/) full node with Docker Compose — one command for either network:

| Network | Token | Chain ID | Geth network ID | Explorer |
|---|---|---|---|---|
| mainnet | JOC | 81 | 81 | https://explorer.japanopenchain.org |
| testnet | JOCT | 10081 | 361257328 | https://explorer.testnet.japanopenchain.org |

Both networks are Clique PoA (5s blocks). Runs Geth `v1.13.5`, the version officially tested by JOC.

## Quick start

```bash
# Mainnet (default)
docker compose up -d

# Testnet
NETWORK=testnet docker compose up -d

# Follow logs
docker compose logs -f
```

No `.env` needed for defaults — official genesis and bootnodes are bundled. Copy `.env.example` to `.env` to change the network persistently, remap ports, or override bootnodes.

On first start the entrypoint runs `geth init` from the bundled genesis, then starts a full sync. `Looking for peers` in the logs means no bootnode connection yet; steady block imports mean syncing. Chain data lands in `./data/<network>/` (gitignored), so mainnet and testnet can coexist.

## Check sync status

```bash
# Current block
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Syncing state (false = fully synced)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

## Endpoints

| Endpoint | Host port (override in `.env`) |
|---|---|
| HTTP JSON-RPC | 8545 |
| WebSocket | 8546 |
| P2P | 30303 (TCP/UDP) |

## Layout

```
docker-compose.yml
genesis/mainnet_genesis.json   # official genesis from japanopenchain.org
genesis/testnet_genesis.json
scripts/entrypoint.sh          # picks network, geth init on first run, full sync
.env.example
data/                          # chain data per network (gitignored)
```

## Notes

- RPC binds `0.0.0.0` inside the container with CORS `*` — fine for local dev; on a public server, do not expose 8545/8546 directly (use a firewall or an authenticated reverse proxy).
- Mainnet has been producing 5s blocks since 2022 — a full sync from genesis takes a while and needs a few hundred GB on SSD. Testnet is lighter.
- Bootnodes are the official ones from the docs (updated Dec 2024). If the node can't find peers, check the docs for newer bootnodes and set `BOOTNODES` in `.env`.
