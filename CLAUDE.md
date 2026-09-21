# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow

Do NOT commit or push automatically. Make changes in the working tree only; the user decides when to commit and push.

## What this is

Docker Compose quickstart for running Japan Open Chain (JOC) full nodes. Mainnet (`joc/`) is Clique PoA on Geth `v1.13.5`, the version officially tested by JOC, with a live (but not-yet-merged) beacon chain alongside it; testnet (`joct/`) is transitioning to PoSA and currently pins Geth `v1.11.6` — the two networks are no longer on the same Geth version, don't assume they are. No build step, no tests; the "code" is compose files, shell entrypoints, and genesis/beacon config files.

## Architecture: joc (mainnet, merge not scheduled) vs joct (testnet, transitioning to PoSA)

Both `joc/` and `joct/` are structured like `posa-sandbox/`: an **execution layer + consensus layer** split, each in its own subfolder —

```
<net>/el/            # execution layer (Geth) — genesis.json, entrypoint.sh
<net>/cl/            # consensus layer (Lighthouse) — entrypoint.sh, config.yaml,
                      #   deposit_contract_block.txt, genesis.ssz
<net>/docker-compose.yml   # <net>-node (geth) + <net>-lighthouse services
<net>/.env.example
```

They are **not** a strict 1:1 mirror beyond that shared shape — mainnet's beacon chain is live and its merge is deliberately *not* scheduled (Clique keeps running on its own), while testnet's merge *is* scheduled; a compose/entrypoint change to one does not automatically apply to the other. Check which side of that distinction a change actually concerns before propagating it.

`joc/cl/config.yaml`, `joc/cl/deposit_contract_block.txt` and `joc/cl/genesis.ssz` are all real, verified values from a live beacon chain (genesis fired 2026-09-18) — sourced from `japan-open-chain/mainnet`'s `metadata/` directory. `joct/cl/config.yaml` and `joct/cl/deposit_contract_block.txt` are bundled, checked-in files (same pattern — `cl/entrypoint.sh` copies them into the datadir on first boot, no `.env` override) holding the network's real decided values, but unverified against a live beacon node — see the DRAFT notice at the top of `config.yaml`. `joct/cl/genesis.ssz` is still a genuine **placeholder** (0 bytes) — beacon genesis hasn't triggered on JOCT yet (gated on `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` deposits landing); lighthouse will not produce a working beacon chain until it's replaced with a real one.

`posa-sandbox/` remains a separate, independent third folder — the original Geth+Lighthouse prep/reference implementation for the PoSA testnet (per the joc-website "Connecting to JOC Nodes" guide, gu-corp/joc-website#357), used as the template both `joc/` and `joct/` were restructured from. It is **not** kept in sync with either going forward — don't propagate changes between them. See `posa-sandbox/README.md` for its sandbox/placeholder-data caveats.

Per-network constants are hardcoded in each entrypoint (network ID, official bootnodes/ENRs, datadir); runtime overrides flow through `.env` → compose `environment:` → entrypoint defaults of the form `${VAR:-default}`. Both networks' EL accepts `BOOTNODES`, `HTTP_APIS`, host ports; both networks' CL accepts `BOOT_ENRS`, beacon host ports. Mainnet's EL additionally accepts `WS_APIS`, `SYNCMODE`, `GCMODE` — testnet's does **not**, since `joct/el/entrypoint.sh` no longer sets `--ws`/`--syncmode`/`--gcmode` at all (see below).

Key facts that are easy to get wrong:

- Testnet chainId is **10081** but the Geth network ID is **361257328** (per official docs). Mainnet is 81 for both.
- Mainnet's Geth explicitly sets `--syncmode full --gcmode full` (JOC's official recommendation) and exposes WebSocket (`--ws`, port 8546). Testnet's Geth entrypoint (`joct/el/entrypoint.sh`) sets neither — it runs on Geth's own default syncmode (`snap`, not `full`) and doesn't expose WebSocket at all. This is a deliberate simplification for the PoSA transition, not an oversight — don't "fix" it by copying mainnet's flags over without checking with the user first.
- Mainnet's beacon chain is live but its merge is **not scheduled**: `joc/cl/config.yaml`'s `TERMINAL_TOTAL_DIFFICULTY` is max uint64 (unreachable), and `joc/el/genesis.json` carries no merge fields — `joc-lighthouse` runs alongside `joc-node` without ever taking over block production. Testnet's `TERMINAL_TOTAL_DIFFICULTY` is a real, reachable number, so its merge is scheduled. Don't assume these two configs mean the same thing just because both have the field set.
- Testnet host ports are offset (18545/30304, beacon 15052/19000) vs mainnet (8545/8546/30303, beacon 5052/9000) so both nodes can run side by side; testnet has no WebSocket port to offset.
- Container ports are 8545/30303 for testnet Geth (no 8546, no WS) vs 8545/8546/30303 for mainnet Geth; both networks' Lighthouse uses 5052/9000 internally. Only host mappings differ from these.
- Chain data: `joc/el/data/mainnet/` (extra network-name level under `data/` is load-bearing — the healthcheck's `geth attach --datadir` path and the JWT secret path under it must match the entrypoint's `DATADIR`; kept intentionally on the restructure to avoid forcing a resync) vs `joct/el/data/` (flat, no network-name level, matching `posa-sandbox/`'s layout). Both networks' `cl/data/` is flat. Don't assume these two EL datadir conventions match.
- The execution/consensus JWT handshake: `<net>/el/entrypoint.sh` generates a JWT secret on first boot (`joc/el/data/mainnet/jwtsecret`, `joct/el/data/jwtsecret` — note the differing depth from the point above); `<net>/cl/entrypoint.sh` mounts that same folder read-only at `/jwt` and polls for the file rather than sharing the whole execution datadir. `joc/cl/entrypoint.sh` therefore waits at `/jwt/mainnet/jwtsecret`, not `/jwt/jwtsecret`.
- `joc-lighthouse` has no `--checkpoint-sync-url` (JOC hasn't published a public beacon RPC endpoint for mainnet) — it syncs from the real, bundled `joc/cl/genesis.ssz` instead. Don't add one without a confirmed official endpoint.
- `LIGHTHOUSE_VERSION` for `joc/` is pinned to `v7.0.1` in `.env.example`, not `latest` — verified by actually running it. `latest` resolved to `v8.2.2` at time of testing and refused to start (`Failed to build beacon chain: The current head state is outside the weak subjectivity period`), because mainnet's beacon chain has only 8 validators and a correspondingly short weak-subjectivity period even a few days after genesis. `v7.0.1` starts and syncs correctly against the same bundled `genesis.ssz`. Don't bump `LIGHTHOUSE_VERSION` back to `latest`/unpinned without re-testing this.
- Bootnodes/genesis come from https://www.japanopenchain.org/en/docs/developer/connect-joc/mainnet/ (testnet via `?type-=testnet`) for the execution layer, and from each network's official metadata repo (`japan-open-chain/mainnet`, testnet's equivalent) for consensus bootnode ENRs and beacon config. Execution bootnodes were verified current as of Dec 2025; earlier ones are dead. If you update them, update both the entrypoint and the "verified as of" notes in README and entrypoint comments.

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
sh -n joc/el/entrypoint.sh joc/cl/entrypoint.sh joct/el/entrypoint.sh joct/cl/entrypoint.sh

# Check sync (mainnet Geth 8545, mainnet Lighthouse 5052, testnet Geth 18545, testnet Lighthouse 15052)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

There is no CI; `docker compose config` + `sh -n` is the whole verification story.
