---
name: dst-restart
description: Restart the Don't Starve Together server, or apply a mod update ("mod outdated"/"mod has new version"), or restart to clear lag — keeping the current world. Use for any "restart the game server" / "update mods" / "server laggy, restart" request on this dst-server-docker repo.
---

# Restart the DST server (keep world)

The server is `dst-master-<branch>` + `dst-caves-<branch>` (branch = active world, see `cat .dst-current`). Use the `dst` CLI (`/usr/local/bin/dst`, symlinked to `cli/dst`).

## Decide which restart
- **Plain restart / mod update / clear lag** → `dst restart` (FAST, in-place). Reuses containers so the image's `22-mods.sh` only re-downloads mods that actually changed, and re-renders `modoverrides.lua`. ~1 min.
- **After changing `.world.env` / `server/docker-compose.yml` env (mod LIST, cluster name)** → `dst restart --fresh` (recreate). Needed because env is baked at container-create time. Re-downloads all mods (~5–7 min).

## Steps
1. Run it (a player may be online — restarting disconnects them ~1 min; that's expected):
   ```
   DST_CALLER=claude dst restart        # or: dst restart --fresh
   ```
   It already waits for cross-shard sync (`wait_for_ready`).
2. Verify BOTH shards came up and connected (do NOT trust the CLI exit alone):
   ```
   docker ps --filter name=dst- --format 'table {{.Names}}\t{{.Status}}'
   docker logs --since 10m dst-master-$(cat .dst-current) 2>&1 | grep 'is now connected' | tail -1
   ```
   Caves connected ⇒ master log shows `World <id>(Caves) is now connected` (or `Resyncing master world option … to secondary shards`).

## Critical principles
- **NEVER auto-stop a running server** to "protect" it — the user is playing. Only verify startup, then stop watching. `wait_for_ready` already does this (it waits + reports, never stops).
- **Always restart BOTH shards together** (the CLI does). Recreating only master while caves keeps running causes a shard-slot conflict → caves can't reconnect.
- **Lag is single-thread CPU, not RAM** — a restart only clears accumulated entities temporarily; it is not a permanent lag fix. Adding swap does nothing for lag. For recurring lag, see `dst-diagnose`.
