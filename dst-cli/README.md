# dst — branch-as-world manager

Each git branch defines a world (mods, configs, server settings). Save state lives in Google Drive, keyed by branch name. The CLI orchestrates: git checkout, rclone sync, docker compose up.

## Layout

```
dst-server-docker/
├── docker-compose.yml      # branch's existing per-world compose (read for env values)
├── config/{Master,Caves}/  # per-shard mod + level overrides (committed)
├── dst-cli/                # untracked (.git/info/exclude)
│   ├── dst                 # the CLI
│   ├── compose.yml         # branch-agnostic compose, mounts ./data/
│   ├── extract-env.py      # parses DST_* env from a docker-compose.yml
│   └── migrate-myth-words.sh
├── data/                   # untracked, bind-mounted save state
│   ├── Master/             # cluster.ini, save/, etc.
│   └── Caves/
├── .world.env              # untracked, generated per-branch (DST_* vars)
└── .dst-current            # untracked, name of active world
```

`dst-cli/`, `data/`, `.world.env`, `.dst-current` are listed in `.git/info/exclude` (local, not committed). They survive `git checkout` between branches.

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
docker compose -f docker-compose.yml down       # stop the old setup
git checkout myth-words                         # already there but be sure
./dst-cli/migrate-myth-words.sh                 # named volumes → ./data/
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

## Switch flow (what `dst switch <branch>` does)

1. Refuses if the working tree is dirty.
2. `git fetch origin`; if branch is remote-only, creates tracking branch.
3. If a world is running:
   - `docker compose down`
   - `rclone sync data/ gdrive:dst-worlds/<current>/` (push save)
4. `git checkout <target> && git pull --ff-only`
5. Wipes `data/Master`, `data/Caves`.
6. `rclone sync gdrive:dst-worlds/<target>/ data/` (pull save; empty if new).
7. Regenerates `.world.env` from the new branch's `docker-compose.yml`.
8. `docker compose up -d`.

## Creating a new world

Use the existing repo workflow — branch off `main`, edit `docker-compose.yml` (cluster name, password, mods, ports), edit `config/Master/*.lua` and `config/Caves/*.lua`, push the branch. Then on the VPS:

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
