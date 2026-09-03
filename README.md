# joc-node-quickstart

Spin up a [Japan Open Chain](https://www.japanopenchain.org/en/docs/developer/connect-joc/mainnet/) full node with Docker Compose. One folder per network — run either, or both side by side:

| Network | Folder | Token | Chain ID | Geth network ID | Explorer |
|---|---|---|---|---|---|
| mainnet | `joc/` | JOC | 81 | 81 | https://explorer.japanopenchain.org |
| testnet | `joct/` | JOCT | 10081 | 361257328 | https://explorer.testnet.japanopenchain.org |

Mainnet is Clique PoA (5s blocks), a single Geth service, full sync (`--syncmode full --gcmode full`, JOC's official recommendation), Geth `v1.13.5`. **Testnet is transitioning to PoSA** and is now an execution+consensus pair (Geth + Lighthouse), structured like `posa-sandbox/` — see `joct/README` notes below; its Geth entrypoint no longer pins `--syncmode`/`--gcmode` or exposes WebSocket, so it runs on Geth's own defaults (snap sync) on `v1.11.6`. `GETH_VERSION` is overridable per network via `.env`. Each folder is fully self-contained: compose file(s), genesis, entrypoint(s), and `.env` all live inside it.

> `joct/cl/genesis.ssz` is still a placeholder (0 bytes) — beacon genesis hasn't triggered on JOCT yet (needs `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` deposits). `joct/cl/config.yaml` and `joct/cl/deposit_contract_block.txt` are filled in with the network's real decided values, but unverified against a live beacon node — see the DRAFT notice at the top of `joct/cl/config.yaml`. `joct` won't fully sync until `genesis.ssz` is real.

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
| WebSocket | 8546 | — (not exposed) |
| P2P (TCP/UDP) | 30303 | 30304 |
| Lighthouse (beacon) HTTP | — | 15052 |
| Lighthouse P2P (TCP/UDP) | — | 19000 |
| Explorer (optional) | 8080 | 18080 |

Override host ports in each folder's `.env`.

## Optional block explorer

Each folder ships an opt-in [ethereum-lite-explorer](https://github.com/Alethio/ethereum-lite-explorer) service — stateless, no database, the browser talks straight to the node's RPC:

```bash
docker compose --profile explorer up -d   # node + explorer
docker compose --profile explorer down    # stop both
```

Then open http://localhost:8080 (mainnet) or http://localhost:18080 (testnet). It browses blocks/txs/accounts live from the node; there is no indexer, so per-address transaction history is not available. `EXPLORER_NODE_URL` must be the RPC URL as seen from your browser (default `http://localhost:8545`) — change it in `.env` if the node runs on a remote host.

## Layout

```
joc/docker-compose.yml         # mainnet node (single Geth service, Clique)
joc/genesis.json               # official genesis from japanopenchain.org
joc/entrypoint.sh              # geth init on first run, then full sync
joc/.env.example
joc/data/                      # chain data (gitignored)

joct/docker-compose.yml        # testnet: joct-node (geth) + joct-lighthouse services
joct/.env.example
joct/el/                       # execution layer (Geth)
  genesis.json                 #   official testnet genesis
  entrypoint.sh                #   geth init + JWT secret generation + start
  data/                        #   chaindata + jwtsecret (gitignored)
joct/cl/                       # consensus layer (Lighthouse)
  entrypoint.sh                #   waits for the JWT secret, then starts beacon_node
  config.yaml                  #   DRAFT — real decided values, unverified against a live chain
  deposit_contract_block.txt   #   deposit contract deployment block (bundled, like config.yaml)
  genesis.ssz                  #   PLACEHOLDER — 0 bytes; beacon genesis hasn't triggered yet
  data/                        #   beacon chain data (gitignored)

posa-sandbox/                  # original Geth+Lighthouse PoSA prep/reference folder that
                                # joct/ was restructured from — kept independent, not synced
                                # with joct/ going forward (see posa-sandbox/README.md)
```

## Notes

- RPC binds `0.0.0.0` inside the container with CORS `*` — fine for local dev; on a public server, do not expose the RPC/WS ports directly (use a firewall or an authenticated reverse proxy).
- Mainnet has been producing 5s blocks since 2022 — a full sync from genesis takes a while and needs a few hundred GB on SSD. Testnet is lighter.
- Mainnet's Geth runs `--syncmode full --gcmode full` (JOC's official recommendation) and exposes WebSocket. Testnet's Geth entrypoint doesn't set `--syncmode`/`--gcmode` or `--ws` at all, so it runs on Geth's own defaults (snap sync, no WebSocket) — a deliberate divergence from mainnet, not an oversight.
- Bootnodes are the official ones from the docs (verified current as of Dec 2025). If the node can't find peers, check the docs for newer bootnodes and set `BOOTNODES` in the folder's `.env`.
- Migrating from the old single-folder layout: move `data/mainnet` to `joc/data/mainnet` to keep synced mainnet chain data.
- Migrating an existing `joct/` node to the new execution/consensus layout: move old chain data from `joct/data/testnet` to `joct/el/data`.
- Testnet's execution and consensus clients authenticate to each other over the Engine API using a JWT secret that `joct/el/entrypoint.sh` generates once at `joct/el/data/jwtsecret`; `joct/cl/entrypoint.sh` mounts that folder read-only and waits for the file rather than sharing the whole execution datadir.
