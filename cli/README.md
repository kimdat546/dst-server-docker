# dst — branch-as-world manager

Each git branch defines a world (mods, configs, server settings). Save state lives in Google Drive, keyed by branch name. The CLI orchestrates: git checkout, rclone sync, docker compose up.

## Layout

```
dst-server-docker/
├── server/
│   ├── docker-compose.yml  # branch's per-world compose (read for env values)
│   └── config/{Master,Caves}/  # per-shard mod + level overrides (committed)
├── cli/
│   ├── dst                 # the CLI
│   ├── compose.yml         # branch-agnostic compose, mounts ../data/
│   ├── extract-env.py      # parses DST_* env from server/docker-compose.yml
│   └── migrate-named-volumes.sh
├── data/                   # untracked, bind-mounted save state
│   ├── Master/             # cluster.ini, save/, etc.
│   └── Caves/
├── .world.env              # untracked, generated per-branch (DST_* vars)
└── .dst-current            # untracked, name of active world
```

`data/`, `.world.env`, `.dst-current` are gitignored (local-only, survive `git checkout` between branches).

## One-time setup

```bash
apt install -y rclone
rclone config
# n) new remote → name: gdrive → storage: drive → scope: drive (or drive.file)
# OAuth in browser, paste token back
rclone mkdir gdrive:dst-worlds
```

The CLI is symlinked at `/usr/local/bin/dst`.

## Migrate the running myth-words world

```bash
cd /root/dst-server-docker
docker compose -f server/docker-compose.yml down  # stop the old setup
git checkout myth-words                           # already there but be sure
./cli/migrate-named-volumes.sh                    # named volumes → ./data/
dst start                                       # boot via the new compose
dst push                                        # first cloud backup
```

After the world is verified working, drop the old named volumes:
```bash
docker volume rm dst-server-docker_dst-master-data-myth-words \
                 dst-server-docker_dst-caves-data-myth-words
```

## Daily use

```bash
dst list                  # branches + which is active/running
dst status                # current state
dst switch speedrun       # stop+push myth-words → checkout speedrun → pull save → start
dst push                  # ad-hoc backup of running world
dst stop                  # stop the world (still active, can resume later)
dst start                 # start the active world
```

## Common operations (the three you'll do most)

| You want to… | Command | What happens |
|---|---|---|
| **Just restart** (clear lag, bounce) — and auto-update only mods that changed | `dst restart` | In-place restart, **reuses containers** → the image's `22-mods.sh` re-downloads **only mods whose Workshop version changed** (none changed = pure bounce). ~1 min. |
| **Apply config you edited** (`.world.env` / compose env: mod LIST, cluster name) | `dst restart --fresh` | Recreates containers (env is baked at create time). Re-downloads all mods. |
| **Fresh world** (new map, keep mods) | `dst reset` | Backs up to Drive (`<world>.pre-reset.tar.gz`) → wipes `data/` → fresh worldgen. Keeps the container so **mods are not re-downloaded**. |
| **Roll back time** (undo recent progress / "reset the day") | `dst rollback [N]` | Kills (no save-over) → moves the latest N autosave snapshots aside (recoverable) → restarts in place. ~N in-game days. |
| **Add/remove/reconfigure a mod** | `dst mod add\|remove\|list [id]`, then `dst restart --fresh` | Edits both shards' `modoverrides.lua` + syncs `DST_SERVER_MOD_SETUP`. Refuses to remove a world-content mod from a live world (would delete its items/buildings). |
| **Fix mod list drift** | `dst sync-mods` | Rewrites `DST_SERVER_MOD_SETUP` (compose + `.world.env`) from `modoverrides.lua` (the single source of truth). |

Why a plain `dst restart` auto-updates mods: DST dedicated servers sync Workshop mods to latest on boot. That's desirable — it prevents the "this server is running an old version of <mod>, you can't join" error. There is no "freeze mods at an old version" restart.

**Lag note:** DST simulation is ~single-thread. Lag = CPU/mod overhead, **not RAM** — adding swap does not fix lag. Diagnose with the `dst-diagnose` agent skill.

## Agent skills

`.claude/skills/dst-*` codify these operations for Claude Code (auto-invoked by request): `dst-restart`, `dst-reset-world`, `dst-rollback`, `dst-edit-mods`, `dst-player-reset`, `dst-backup-restore`, `dst-diagnose`. They wrap the `dst` CLI and embed the hard-won safety rules (never auto-stop a running server, restart both shards together, world-content-mod removal warning, snapshot-size recovery).

## Switch flow (what `dst switch <branch>` does)

1. Refuses if the working tree is dirty.
2. `git fetch origin`; if branch is remote-only, creates tracking branch.
3. If a world is running:
   - `docker compose down`
   - `rclone sync data/ gdrive:dst-worlds/<current>/` (push save)
4. `git checkout <target> && git pull --ff-only`
5. Wipes `data/Master`, `data/Caves`.
6. `rclone sync gdrive:dst-worlds/<target>/ data/` (pull save; empty if new).
7. Regenerates `.world.env` from the new branch's `server/docker-compose.yml`.
8. `docker compose up -d`.

## Creating a new world

Use the existing repo workflow — branch off `main`, edit `server/docker-compose.yml` (cluster name, password, mods, ports), edit `server/config/Master/*.lua` and `server/config/Caves/*.lua`, push the branch. Then on the VPS:

```bash
dst switch <new-branch>
```

The first run boots a fresh world (no save data on Drive yet). On the next switch away, save data uploads to `gdrive:dst-worlds/<new-branch>/`.

## Sync hygiene

`rclone` excludes:
- `*/server/general/*/backup/**` — DST's auto-backups (regenerated, ~2GB/world)
- `**/server_log.txt*`, `**/server_chat_log.txt*` — logs
- `**/mods/**`, `**/ugc_mods/**` — Steam Workshop downloads (re-fetched on start)
- `**/Agreements/**`, `**/steamcmd/**`, `**/steamapps/**` — Steam state

Per-world cloud footprint: ~150MB instead of ~2.2GB.

Override the remote with `DST_REMOTE=gdrive:custom/path dst push`.
