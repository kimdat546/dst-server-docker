# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a Docker image for running a [Don't Starve Together](https://www.kleientertainment.com/games/dont-starve-together) dedicated server. It is built on top of `ghcr.io/dockhippie/steamcmd` and installs the DST dedicated server (Steam App ID `343050`) at build time.

Images are published to:
- `webhippie/dst` (Docker Hub)
- `quay.io/webhippie/dst`
- `ghcr.io/dockhippie/dst`

## Building

```bash
docker build -f image/Dockerfile.amd64 image/
```

CI builds are triggered by pushes to `master` via `.github/workflows/docker.yml`.

## Architecture

All configuration is done via `DST_*` environment variables. The only required variable at runtime is `DST_CLUSTER_TOKEN`.

### Execution Flow

The container entrypoint is `/usr/bin/container`, which:
1. Sources `/usr/bin/entrypoint` (from the parent steamcmd image)
2. Sources scripts in `/etc/container.d/` in sorted order (00–25):
   - `00-user.sh` — user setup
   - `05-upgrade.sh` — runs `steamcmd` to update the game (unless `DST_SKIP_GAME_UPGRADE=true`)
   - `10-dirs.sh` — creates required directories
   - `15-files.sh` — creates required files (token, admin/block/whitelist)
   - `20-configs.sh` — uses `gomplate` to render all config templates
   - `25-chown.sh` — adjusts file ownership
3. Starts the DST server as the `steam` user via `su-exec`

### Environment Variable Defaults

Default values for all `DST_*` variables are declared in `/etc/entrypoint.d/` scripts (sourced by the parent image's entrypoint before `container.d`):
- `05-base.sh` — paths, file locations, skip flags
- `10-cluster.sh` — gameplay, network, shard, steam settings
- `15-settings.sh` — server port, shard role, steam ports
- `20-overrides.sh` — world generation overrides; applies preset defaults for `Master` (forest) or `Caves` shard based on `DST_OVERRIDE_PRESET`
- `25-mods.sh` — mod configuration variables

### Config Templates

`gomplate` renders templates from `/etc/templates/` into the game's config directories:

| Template | Output |
|---|---|
| `cluster.ini.tmpl` | `$DST_CLUSTER_CONFIG_FILE` |
| `server.ini.tmpl` | `$DST_SERVER_CONFIG_FILE` |
| `modoverrides.lua.tmpl` | `$DST_MOD_OVERRIDES_FILE` |
| `leveldataoverride.lua.tmpl` | `$DST_LEVELDATA_OVERRIDE_FILE` |
| `dedicated_server_mods_setup.lua.tmpl` | `$DST_MOD_SETUP_FILE` |
| `modsettings.lua.tmpl` | `$DST_MOD_SETTINGS_FILE` |

Each config step can be skipped with `DST_SKIP_<STEP>=true`.

### Mod Setup

- `DST_SERVER_MOD_SETUP` — comma-separated Steam Workshop mod IDs to install and enable
- `DST_SERVER_MOD_COLLECTION_SETUP` — comma-separated Steam Workshop collection IDs
- `DST_WORKSHOP_<MOD_ID>` — per-mod configuration options (Lua key=value pairs)
- `DST_MOD_OVERRIDES_RAW` — raw Lua to inject directly into `modoverrides.lua`
- `DST_FORCE_ENABLE_MODS` — force-enable specific mods

### Shard (Multi-Level) Setup

For caves/multi-shard setups, run two containers with shared storage:
- Master shard: `DST_SHARD_ENABLED=true`, `DST_SHARD_IS_MASTER=true`
- Cave shard: `DST_SHARD_ENABLED=true`, `DST_SHARD_IS_MASTER=false`, `DST_SHARD_NAME=Caves`, `DST_SHARD_MASTER_IP=<master-ip>`

## Running a live server (the `dst` CLI)

This repo also operates a live VPS server (master + caves shards, branch = world). Manage it with the **`dst` CLI** (`cli/dst`, symlinked at `/usr/local/bin/dst`) — never hand-roll `docker compose` for routine ops. Run `dst help`.

Common operations:
- `dst restart` — fast in-place restart; reuses containers so only **changed** mods re-download (the image's `22-mods.sh` is incremental). Covers both "just restart" and "update outdated mods". Use `dst restart --fresh` only after editing `.world.env`/compose env (mod list, cluster name).
- `dst reset` — fresh world (backs up to Drive first; keeps mod cache → fast).
- `dst rollback [N]` — roll back N autosaves (~N days); recoverable.
- `dst mod add|remove|list` + `dst sync-mods` — `modoverrides.lua` (both shards, identical) is the single source of truth for enabled mods; `DST_SERVER_MOD_SETUP` is derived.
- `dst push` / `dst pull` — Google Drive backup/restore.

Hard-won operational rules (see `.claude/skills/dst-*` and the project memory dir):
- **Never auto-stop a running server** to "protect" it — players may be online; verify startup then stop watching.
- **Restart both shards together** — recreating only master while caves runs causes a shard-slot conflict (caves can't reconnect).
- **Lag = single-thread CPU / mod overhead, NOT RAM** — adding swap does not fix lag (this VPS is 3.8GB + 4GB swap; OOM is a separate issue).
- **Removing a world-content mod from a live world deletes its items/buildings** — only safe on a fresh world.
- **`c_rollback` can't be sent from the host** (stdin = /dev/null) — use `dst rollback` (file-level snapshot rollback).
- A character with **>63 net tags** (e.g. Wurt + heavy mods) triggers `Error serializing tags … exceeds maximum size of 63` → disconnects.

Agent skills in `.claude/skills/`: `dst-restart`, `dst-reset-world`, `dst-rollback`, `dst-edit-mods`, `dst-player-reset`, `dst-backup-restore`, `dst-diagnose`.

## Commit Convention

Commits must follow semantic format: `type: message`

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`, `major`, `minor`, `patch`, `deps`
