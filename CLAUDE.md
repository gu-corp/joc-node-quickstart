# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow

Do NOT commit or push automatically. Make changes in the working tree only; the user decides when to commit and push.

## What this is

Docker Compose quickstart for running Japan Open Chain (JOC) full nodes — a Clique PoA Ethereum chain, Geth `v1.13.5` (the version officially tested by JOC). No build step, no tests; the "code" is compose files, shell entrypoints, and genesis JSON.

## Architecture: two self-contained folders, duplication is intentional

`joc/` (mainnet) and `joct/` (testnet) each bundle their own `docker-compose.yml`, `genesis.json`, `entrypoint.sh`, and `.env.example`. Nothing is shared between them — this was a deliberate choice (over compose profiles or a shared entrypoint) so each folder can be copied to a separate server as-is and can diverge independently. **A change to one folder's compose file or entrypoint usually needs mirroring in the other** unless it is genuinely network-specific.

Per-network constants are hardcoded in each `entrypoint.sh` (network ID, official bootnodes, datadir); runtime overrides (`BOOTNODES`, `HTTP_APIS`, `WS_APIS`, host ports) flow through `.env` → compose `environment:` → entrypoint defaults of the form `${VAR:-default}`.

Key facts that are easy to get wrong:

- Testnet chainId is **10081** but the Geth network ID is **361257328** (per official docs). Mainnet is 81 for both.
- Testnet host ports are offset (18545/18546/30304 vs mainnet 8545/8546/30303) so both nodes can run side by side.
- Container ports are always 8545/8546/30303; only host mappings differ.
- Chain data lands in `joc/data/mainnet/` and `joct/data/testnet/` (gitignored). The extra network-name level under `data/` is load-bearing — the healthcheck's `geth attach --datadir` path must match the entrypoint's `DATADIR`.
- Bootnodes/genesis come from https://www.japanopenchain.org/en/docs/developer/connect-joc/mainnet/ (testnet via `?type-=testnet`). Bootnodes were verified current as of Dec 2025; earlier ones are dead. If you update them, update both the entrypoint and the "verified as of" notes in README and entrypoint comments.

## Commands

```bash
# Run a node (from joc/ or joct/)
docker compose up -d
docker compose logs -f

# Validate after editing compose files (run in each changed folder)
docker compose config --quiet

# Syntax-check entrypoints after editing
sh -n joc/entrypoint.sh joct/entrypoint.sh

# Check sync (mainnet 8545, testnet 18545)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

There is no CI; `docker compose config` + `sh -n` is the whole verification story.
