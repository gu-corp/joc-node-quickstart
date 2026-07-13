# joc-node-quickstart

Spin up a [Japan Open Chain](https://www.japanopenchain.org/en/docs/developer/connect-joc/mainnet/) full node with Docker Compose. One folder per network — run either, or both side by side:

| Network | Folder | Token | Chain ID | Geth network ID | Explorer |
|---|---|---|---|---|---|
| mainnet | `joc/` | JOC | 81 | 81 | https://explorer.japanopenchain.org |
| testnet | `joct/` | JOCT | 10081 | 361257328 | https://explorer.testnet.japanopenchain.org |

Both networks are Clique PoA (5s blocks). Runs Geth `v1.13.5`, the version officially tested by JOC. Each folder is fully self-contained: compose file, genesis, entrypoint, and `.env` all live inside it.

## Quick start

```bash
# Mainnet
cd joc && docker compose up -d

# Testnet
cd joct && docker compose up -d

# Follow logs (from the network's folder)
docker compose logs -f
```

Both can run at the same time — host ports don't overlap (see below). No `.env` needed for defaults — official genesis and bootnodes are bundled. Copy `.env.example` to `.env` inside a network folder to remap ports or override bootnodes for that network.

On first start the entrypoint runs `geth init` from the bundled genesis, then starts a full sync. `Looking for peers` in the logs means no bootnode connection yet; steady block imports mean syncing. Chain data lands in `<folder>/data/` (gitignored).

## Check sync status

```bash
# Current block (mainnet: 8545, testnet: 18545)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Syncing state (false = fully synced)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

## Endpoints

| Endpoint | Mainnet (`joc/`) | Testnet (`joct/`) |
|---|---|---|
| HTTP JSON-RPC | 8545 | 18545 |
| WebSocket | 8546 | 18546 |
| P2P (TCP/UDP) | 30303 | 30304 |

Override host ports in each folder's `.env`.

## Layout

```
joc/docker-compose.yml         # mainnet node
joc/genesis.json               # official genesis from japanopenchain.org
joc/entrypoint.sh              # geth init on first run, then full sync
joc/.env.example
joct/docker-compose.yml        # testnet node (same layout as joc/)
joct/genesis.json
joct/entrypoint.sh
joct/.env.example
joc/data/, joct/data/          # chain data per network (gitignored)
```

## Notes

- RPC binds `0.0.0.0` inside the container with CORS `*` — fine for local dev; on a public server, do not expose the RPC/WS ports directly (use a firewall or an authenticated reverse proxy).
- Mainnet has been producing 5s blocks since 2022 — a full sync from genesis takes a while and needs a few hundred GB on SSD. Testnet is lighter.
- Bootnodes are the official ones from the docs (updated Dec 2024). If the node can't find peers, check the docs for newer bootnodes and set `BOOTNODES` in the folder's `.env`.
- Migrating from the old single-folder layout: move `data/mainnet` to `joc/data/mainnet` and `data/testnet` to `joct/data/testnet` to keep synced chain data.
