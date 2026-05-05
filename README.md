# Don't Starve Together Dedicated Server (Docker)

[![Docker Build](https://github.com/dockhippie/dst/actions/workflows/docker.yml/badge.svg)](https://github.com/dockhippie/dst/actions/workflows/docker.yml)

Docker image for running a [Don't Starve Together][upstream] dedicated server, with a multi-world management system backed by Google Drive.

## Concept

Each **git branch = one world** (mods, settings, world gen config). Save data lives on **Google Drive**, not on the VPS. The `dst` CLI and Discord bot let you switch worlds, start/stop the server, and manage everything without touching the terminal.

```
myth-words branch  →  modoverrides.lua, docker-compose.yml (cluster name, mods, ports)
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

- `docker-compose.yml` — cluster name, password, mods (`DST_SERVER_MOD_SETUP`), ports
- `config/Master/modoverrides.lua` + `leveldataoverride.lua`
- `config/Caves/modoverrides.lua` + `leveldataoverride.lua`

### 4. Start

```bash
dst start
```

First run pulls the `webhippie/dst` image from Docker Hub and downloads the world save from Drive (or starts fresh if none).

## Creating a new world

```bash
git checkout -b my-new-world
# edit docker-compose.yml, config/Master/*.lua, config/Caves/*.lua
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
```

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

A Discord bot lives in `dst-cli/bot/`. Members in `#dst-control` can manage the server without SSH access.

### Bot setup

```bash
cd dst-cli/bot
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

```
dst-server-docker/
├── docker-compose.yml          # per-branch world config (mods, name, ports)
├── config/
│   ├── Master/
│   │   ├── modoverrides.lua
│   │   └── leveldataoverride.lua
│   └── Caves/
│       ├── modoverrides.lua
│       └── leveldataoverride.lua
├── dst-cli/
│   ├── dst                     # CLI (symlinked to /usr/local/bin/dst)
│   ├── compose.yml             # branch-agnostic compose (bind mounts ./data/)
│   ├── extract-env.py          # parses DST_* vars from docker-compose.yml
│   ├── migrate-named-volumes.sh # one-time migration from old named volumes
│   └── bot/
│       ├── bot.py              # Discord bot
│       ├── requirements.txt
│       └── .bot.env.example    # config template (copy to .bot.env)
└── latest/
    └── Dockerfile.amd64
```

**Gitignored (local only):** `data/`, `.world.env`, `.dst-current`, `dst-cli/bot/.bot.env`, `dst-cli/bot/venv/`

## Available environment variables

See `docker-compose.yml` for the variables used per branch. Full list:

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
