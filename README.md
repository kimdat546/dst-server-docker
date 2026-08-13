# Don't Starve Together Dedicated Server (Docker)

[![Docker Build](https://github.com/dockhippie/dst/actions/workflows/docker.yml/badge.svg)](https://github.com/dockhippie/dst/actions/workflows/docker.yml)

Docker image for running a [Don't Starve Together][upstream] dedicated server, with a multi-world management system backed by Google Drive.

## Concept

Each **git branch = one world** (mods, settings, world gen config). Save data lives on **Google Drive**, not on the VPS. The `dst` CLI and Discord bot let you switch worlds, start/stop the server, and manage everything without touching the terminal.

```
myth-words branch  →  server/config/*.lua, server/docker-compose.yml (cluster name, mods, ports)
speedrun branch    →  different mods + settings
              ↕
       Google Drive: dst-worlds/myth-words.tar.gz, speedrun.tar.gz ...
              ↕
          VPS: only holds data/ while a world is actively running (~50MB)
```

## Quick Setup

### Prerequisites

- Docker + Docker Compose
- A DST cluster token from the [Klei Account Portal](https://accounts.klei.com/account/game/servers?game=DontStarveTogether)
- `rclone` configured with a Google Drive remote named `dst-storage`
- A Discord bot (optional, for remote control)

### 1. Configure rclone

```bash
apt install -y rclone
rclone config   # add remote: name=dst-storage, type=drive
rclone mkdir dst-storage:dst-worlds
```

### 2. Clone and pick a world branch

```bash
git clone https://github.com/kimdat546/dst-server-docker
cd dst-server-docker
git checkout myth-words   # or speedrun, or create your own branch
```

### 3. Edit world config

- `server/docker-compose.yml` — cluster name, password, mods (`DST_SERVER_MOD_SETUP`), ports
- `server/config/Master/modoverrides.lua` + `leveldataoverride.lua`
- `server/config/Caves/modoverrides.lua` + `leveldataoverride.lua`

The Klei cluster token is **not** in any of those — this repo is public. Copy
`tokens.env.example` to `tokens.env` (git-ignored) or run `dst token add`:

```bash
dst token add chinh 'pds-...'   # store a token
dst token list                  # which tokens exist, which one is active
dst token use chinh             # switch to it
dst restart --fresh             # apply to a running server
```

`tokens.env` sits at the repo root, so `git checkout` / `dst switch` never
touches it — one token store shared by every world.

### 4. Start

```bash
dst start
```

First run pulls the `kimdat546/dst-server` image from Docker Hub and downloads the world save from Drive (or starts fresh if none).

## Creating a new world

```bash
git checkout -b my-new-world
# edit server/docker-compose.yml, server/config/Master/*.lua, server/config/Caves/*.lua
git add -A && git commit -m "feat: my-new-world"
git push origin my-new-world
# on the VPS:
dst switch my-new-world
```

## dst CLI

```
dst list                   list branches + cloud saves
dst status                 current world, container health, Drive save size
dst current                print active world name
dst start  [branch]        pull save from Drive → start containers
dst stop   [branch]        stop containers → push save to Drive → clear VPS
dst switch <branch>        stop+push current → git checkout → pull save → start
dst push   [branch]        compress & upload save to Drive manually
dst pull   <branch>        download & extract save from Drive
dst destroy                stop+push, remove all Docker containers/image/volumes
dst token list|use|add|rm  manage Klei cluster tokens (stored outside git)
```

### Changing the cluster token

`DST_CLUSTER_TOKEN` alone is **not** enough on an existing world: the server
reads the token from `data/<shard>/server/general/cluster_token.txt` inside the
data volume, and the image only creates that file when it is missing
(`image/overlay/etc/container.d/15-files.sh`). `dst init` therefore rewrites
both shards' token files from the active token — which `dst token use` calls
for you. Verify the switch took effect with:

```bash
docker logs dst-master-<world> | grep "from TokenPurpose"   # shows the KU_ id now hosting
```

Swapping tokens does not touch the world, characters, or admin rights.

### How stop/start works (VPS storage)

The VPS holds world data **only while the server is running**:
- `dst stop` → compresses `data/` (~8MB), uploads to Drive, deletes `data/` from VPS
- `dst start` → downloads from Drive, extracts, starts containers
- `dst destroy` → same as stop + removes the Docker image (~3GB) — use when taking a long break

### Safety

- Push failure aborts the switch — world stays stopped, data stays local
- Pull extracts to a temp dir and swaps atomically — failed download leaves local data untouched
- Previous save kept as `<world>.bak.tar.gz` on Drive before each overwrite

## Discord Bot

A Discord bot lives in `bot/`. Members in `#dst-control` can manage the server without SSH access.

### Bot setup

```bash
cd bot
python3 -m venv venv
venv/bin/pip install -r requirements.txt
cp .bot.env.example .bot.env
# edit .bot.env — add DISCORD_TOKEN, DST_CONTROL_CHANNEL_ID, DST_GUILD_ID, DISCORD_WEBHOOK_URL
systemctl enable --now dst-bot   # systemd unit at /etc/systemd/system/dst-bot.service
```

### Bot commands (in #dst-control)

| Command | Description |
|---|---|
| `/worlds` | Dropdown menu — pick a world to switch to |
| `/list` | All branches with running/active markers |
| `/status` | Current world, container health, Drive save size |
| `/start` | Start the current world |
| `/stop` | Stop + push to Drive |
| `/switch <branch>` | Switch worlds (with autocomplete) |
| `/push` | Manual Drive backup |
| `/destroy` | Stop + push + remove all Docker resources (asks for confirmation) |

### Webhook notifications

The bot posts to `#dst-control` automatically on: server start 🟢, server stop 🔴, world switch 🔄, destroy 💣. Set `DISCORD_WEBHOOK_URL` in `.bot.env`.

## Repository layout

The repo is split into four top-level concerns that change at different rates:

```
dst-server-docker/
├── image/                      # Docker image build (rarely changes)
│   ├── Dockerfile.amd64
│   └── overlay/                # entrypoint scripts, config templates
├── server/                     # per-branch world config (changes per world)
│   ├── docker-compose.yml      # cluster name, mods, ports
│   └── config/
│       ├── Master/{modoverrides,leveldataoverride}.lua
│       └── Caves/{modoverrides,leveldataoverride}.lua
├── cli/                        # branch-as-world manager
│   ├── dst                     # CLI (symlinked to /usr/local/bin/dst)
│   ├── compose.yml             # branch-agnostic compose (bind mounts ./data/)
│   ├── extract-env.py          # parses DST_* vars from server/docker-compose.yml
│   └── migrate-named-volumes.sh
├── bot/                        # Discord bot
│   ├── bot.py
│   ├── requirements.txt
│   └── .bot.env.example
└── .github/workflows/docker.yml  # builds + publishes the image on image/** changes
```

**Gitignored (local only):** `data/`, `.world.env`, `.dst-current`, `bot/.bot.env`, `bot/venv/`

## Image publishing

The image is built by `.github/workflows/docker.yml` and pushed to Docker Hub as `kimdat546/dst-server`. The workflow runs on pushes to `main` that touch `image/**` (or `.github/workflows/docker.yml`), and on PRs against `main` (build-only, no push). Tags published:

- `:latest` — from `main` (default branch)
- `:main` — same content as `:latest`
- `:sha-<short>` — every build, immutable, for pinning a specific version

To rebuild without a code change (e.g. refresh the DST baseline), trigger it manually:
```
gh workflow run docker.yml --ref main
```

**Required GitHub repo secrets** (Settings → Secrets and variables → Actions):
- `DOCKERHUB_USERNAME` — your Docker Hub username (`kimdat546`)
- `DOCKERHUB_TOKEN` — a Docker Hub access token (Account Settings → Security → New Access Token, scope: Read & Write)

To pin the runtime to a specific image tag (e.g. while debugging), override per-shell:
```
DST_IMAGE=kimdat546/dst-server:sha-abc1234 dst start
```

## Available environment variables

See `server/docker-compose.yml` for the variables used per branch. Full list:

```
DST_CLUSTER_TOKEN          (required) Klei server token
DST_NETWORK_CLUSTER_NAME   server name in browser
DST_NETWORK_CLUSTER_PASSWORD
DST_GAMEPLAY_MAX_PLAYERS
DST_GAMEPLAY_GAME_MODE     survival | endless | wilderness
DST_NETWORK_SERVER_PORT    default 11999
DST_SHARD_MASTER_PORT      default 11888
DST_SHARD_CLUSTER_KEY
DST_SERVER_MOD_SETUP       comma-separated Workshop IDs
```

Full variable reference: [webhippie/dst on Docker Hub][dockerhub]

## License

MIT

[upstream]: https://www.kleientertainment.com/games/dont-starve-together
[dockerhub]: https://hub.docker.com/r/webhippie/dst/tags
