# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow

Do NOT commit or push automatically. Make changes in the working tree only; the user decides when to commit and push.

## What this is

Docker Compose quickstart for running Japan Open Chain (JOC) full nodes. Mainnet (`joc/`) is Clique PoA on Geth `v1.13.5`, the version officially tested by JOC; testnet (`joct/`) is transitioning to PoSA and currently pins Geth `v1.11.6` — the two networks are no longer on the same Geth version, don't assume they are. No build step, no tests; the "code" is compose files, shell entrypoints, and genesis JSON.

## Architecture: joc (Clique) vs joct (transitioning to PoSA) — no longer a strict mirror

`joc/` (mainnet) is a single self-contained Clique PoA node: `docker-compose.yml`, `genesis.json`, `entrypoint.sh`, `.env.example` at its top level, one Geth service.

`joct/` (testnet) has started following JOC's PoSA migration and is now structured like `posa-sandbox/`: an **execution layer + consensus layer** split, each in its own subfolder —

```
joct/el/            # execution layer (Geth) — genesis.json, entrypoint.sh
joct/cl/            # consensus layer (Lighthouse) — entrypoint.sh, config.yaml,
                     #   deposit_contract_block.txt, genesis.ssz
joct/docker-compose.yml   # joct-node (geth) + joct-lighthouse services
joct/.env.example
```

Because of this, **joc/ and joct/ no longer mirror 1:1** — a compose/entrypoint change to one does not automatically apply to the other; check which side (Clique-only vs execution+consensus) a change actually concerns before propagating it.

`joct/cl/config.yaml` and `joct/cl/deposit_contract_block.txt` are bundled, checked-in files (same pattern — `cl/entrypoint.sh` copies them into the datadir on first boot, no `.env` override) holding the network's real decided values, but unverified against a live beacon node — see the DRAFT notice at the top of `config.yaml`. `joct/cl/genesis.ssz` is still a genuine **placeholder** (0 bytes) — beacon genesis hasn't triggered on JOCT yet (gated on `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` deposits landing); lighthouse will not produce a working beacon chain until it's replaced with a real one.

`posa-sandbox/` remains a separate, independent third folder — the original Geth+Lighthouse prep/reference implementation for the PoSA testnet (per the joc-website "Connecting to JOC Nodes" guide, gu-corp/joc-website#357), used as the template `joct/` was restructured from. It is **not** kept in sync with `joct/` going forward — don't propagate changes between them. See `posa-sandbox/README.md` for its sandbox/placeholder-data caveats.

Per-network constants are hardcoded in each entrypoint (network ID, official bootnodes, datadir); runtime overrides flow through `.env` → compose `environment:` → entrypoint defaults of the form `${VAR:-default}`. Mainnet (`joc/`) accepts `BOOTNODES`, `HTTP_APIS`, `WS_APIS`, `SYNCMODE`, `GCMODE`, host ports. Testnet (`joct/`) accepts `BOOTNODES`, `HTTP_APIS`, `BOOT_ENRS`, host ports — **not** `WS_APIS`/`SYNCMODE`/`GCMODE`, since `joct/el/entrypoint.sh` no longer sets `--ws`/`--syncmode`/`--gcmode` at all (see below).

Key facts that are easy to get wrong:

- Testnet chainId is **10081** but the Geth network ID is **361257328** (per official docs). Mainnet is 81 for both.
- Mainnet's Geth explicitly sets `--syncmode full --gcmode full` (JOC's official recommendation) and exposes WebSocket (`--ws`, port 8546). Testnet's Geth entrypoint (`joct/el/entrypoint.sh`) sets neither — it runs on Geth's own default syncmode (`snap`, not `full`) and doesn't expose WebSocket at all. This is a deliberate simplification for the PoSA transition, not an oversight — don't "fix" it by copying mainnet's flags over without checking with the user first.
- Testnet host ports are offset (18545/30304 vs mainnet 8545/8546/30303) so both nodes can run side by side; testnet has no WebSocket port to offset. Testnet's beacon ports (15052/19000) follow the same "prefix 1" offset used for its execution ports.
- Container ports are 8545/30303 for testnet Geth (no 8546, no WS) vs 8545/8546/30303 for mainnet Geth, and 5052/9000 for testnet's Lighthouse; only host mappings differ from these.
- Chain data: `joc/data/mainnet/` (extra network-name level under `data/` is load-bearing — the healthcheck's `geth attach --datadir` path must match the entrypoint's `DATADIR`) vs `joct/el/data/` and `joct/cl/data/` (flat, no network-name level, matching `posa-sandbox/`'s layout). Don't assume these two datadir conventions match.
- The execution/consensus JWT handshake: `joct/el/entrypoint.sh` generates `joct/el/data/jwtsecret` on first boot; `joct/cl/entrypoint.sh` mounts that same folder read-only at `/jwt` and polls for the file rather than sharing the whole execution datadir.
- Bootnodes/genesis come from https://www.japanopenchain.org/en/docs/developer/connect-joc/mainnet/ (testnet via `?type-=testnet`). Bootnodes were verified current as of Dec 2025; earlier ones are dead. If you update them, update both the entrypoint and the "verified as of" notes in README and entrypoint comments.

## Commands

```bash
# Run a node (from joc/ or joct/)
docker compose up -d
docker compose logs -f

# Node + optional stateless explorer (lite-explorer; mainnet :8080, testnet :18080)
docker compose --profile explorer up -d

# Validate after editing compose files (run in each changed folder)
docker compose config --quiet

# Syntax-check entrypoints after editing
sh -n joc/entrypoint.sh joct/el/entrypoint.sh joct/cl/entrypoint.sh

# Check sync (mainnet Geth 8545, testnet Geth 18545, testnet Lighthouse 15052)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

There is no CI; `docker compose config` + `sh -n` is the whole verification story.
