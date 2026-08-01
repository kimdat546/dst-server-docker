---
name: dst-new-world
description: Set up a brand-new Don't Starve Together world from scratch — a new branch/world with its own mod set and world settings (cluster name, overrides, modoverrides). Use for "set up a new world", "create a new server/world", "new world with new mods", "tạo world mới với mod mới" (distinct from dst-reset-world, which regenerates the SAME world).
---

# Create a new world (new branch + new mods)

This repo is **branch-as-world**: each git branch carries its own `server/docker-compose.yml` + `server/config/{Master,Caves}/{leveldataoverride,modoverrides}.lua`. A new world = a new branch with new config. Save state syncs to Drive keyed by branch name.

## Inputs to collect from the user (ask if missing)
- **Branch/world name** (also the in-game cluster name unless they want a different display name).
- **Cluster**: name, description, password, max players, game mode (endless/survival), ports.
- **Mod set**: Workshop IDs + their `configuration_options` — easiest if the user pastes the in-game export of `modoverrides.lua` (Master & Caves) and `leveldataoverride.lua` (forest + cave), like the existing `uncompromising` configs.
- **World overrides**: `world_size`, season/boss settings, etc. (or copy an existing branch's leveldataoverride and tweak).

## Steps
1. Branch off a clean base (commit/stash first; `dst switch` requires a clean tree):
   ```
   git checkout main && git checkout -b <newbranch>
   ```
2. Scaffold from an existing world (fastest), then edit:
   ```
   git checkout uncompromising -- server/docker-compose.yml server/config
   ```
   - Edit `server/docker-compose.yml`: `DST_NETWORK_CLUSTER_NAME/_DESCRIPTION`, `_PASSWORD`, `DST_GAMEPLAY_MAX_PLAYERS/_GAME_MODE`, ports, `container_name` is `dst-*-${DST_BRANCH}` (cli compose) — keep token unless they want a new one.
   - Overwrite the 4 config files with the user's `modoverrides.lua` (Master + **identical** Caves) and `leveldataoverride.lua` (Master forest + Caves cave). Keep Master==Caves modoverrides.
3. Make the mod list the single source of truth:
   ```
   dst sync-mods   # derives DST_SERVER_MOD_SETUP (compose + .world.env) from modoverrides
   ```
4. Commit on the new branch:
   ```
   git add server/docker-compose.yml server/config && git commit -m "feat: new world <newbranch>"
   ```
5. Boot it (switch handles stop+push of the current world, checkout, init, start):
   ```
   DST_CALLER=claude dst switch <newbranch>
   ```
   (Or if already on the branch with no current world running: `dst init && dst start`.)
6. **Verify** like `dst-restart`/`dst-reset-world`: both shards up, caves connected, and watch the master log for a worldgen retry loop (`An error occured during world gen … retry` ≥6) — see notes below.

## Gotchas (from past setups)
- **`world_size`**: `"small"` + heavy mods can loop worldgen if a required setpiece can't be placed. It can work, but if it loops, bump to `"default"`. Check master log.
- **Mods must be in both** `modoverrides.lua` (enables) **and** `DST_SERVER_MOD_SETUP` (downloads) — `dst sync-mods` guarantees this. Master and Caves modoverrides must be identical.
- **Tag limit**: a heavy mod set + a merm character (Wurt) can exceed the 63 net-tag limit → players disconnect. If the new world will allow Wurt, keep the mod set lean (see `dst-edit-mods` / memory `mod-removal-world-content`).
- **Network**: `DST_SHARD_MASTER_IP=127.0.0.1` + `network_mode: host` is correct for this single-VPS master+caves — don't change it.
- VPS is 3.8GB + 4GB swap; master+caves+~20 mods is the practical ceiling.

First boot generates a fresh world; on the next `dst switch` away, the save uploads to Drive as `<newbranch>.tar.gz`.
