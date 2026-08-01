---
name: dst-edit-mods
description: Add, remove, or reconfigure a Workshop mod on the Don't Starve Together server. Use for "add mod X", "remove mod X", "change mod config / mod options", "update the mod list". Keeps the two shards in sync and guards against breaking a live world.
---

# Edit the mod set

`server/config/Master/modoverrides.lua` is the **single source of truth** for enabled mods + their config. `server/config/Caves/modoverrides.lua` must be **identical**. `DST_SERVER_MOD_SETUP` (in `server/docker-compose.yml` + `.world.env`) is **derived** from it.

## Add / remove a mod
```
DST_CALLER=claude dst mod list                 # see enabled mods
DST_CALLER=claude dst mod add <workshop_id>     # adds to BOTH shards (empty config) + syncs lists
DST_CALLER=claude dst mod remove <workshop_id>  # removes from BOTH shards + syncs; guards world-content
```
Then apply: `dst restart --fresh` (mod-LIST changes live in env → need recreate).

## Change a mod's config options
1. Edit the `configuration_options={…}` block in **`server/config/Master/modoverrides.lua`**.
2. Mirror it to Caves: `cp server/config/Master/modoverrides.lua server/config/Caves/modoverrides.lua` (or edit both identically), then `diff -q` them.
3. Config-only change (no mod added/removed) applies on a normal restart: `dst restart`. (modoverrides is re-rendered on every container start.)

## ⚠️ Removing a mod from a LIVE world is dangerous
Removing a **world-content** mod (one that places entities — items, buildings, mobs, scenarios) from a world that's already using it **permanently deletes those entities** on next load (and can break loading entirely, e.g. orphaned scenarios like `random_farmplot`). Past incident: removing Heap of Foods stripped ~half the world (5.2MB→2.8MB).
- `dst mod remove` **refuses** to remove a known world-content mod while the server is running.
- World-content mods (don't remove on a live world): Heap of Foods `2334209327`, Island Adventures Core `3435352667` + Shipwrecked `1467214795`, Beneath the World Below `3360553731`, Dehydrated `3004639365`, Pond OceanTree `3675508496`, Fast Travel sign `3353852416`, Smart Minisign `1595631294`, Uncompromising `2039181790`.
- Safe to remove anytime (UI/tweak only, no world entities): Show Me `666155465`, Show Bundle `1111658995`, Simple Health Bar `1207269058`, Auto Stack `1803285852`, Quick Pick `501385076`, Increased Stack `374550642`, Mineable Gems `380423963`, Fast Pigking `1780476441`, Extra Equip Slots `375850593`, Performance Pack `2847908822`.
- To truly drop a world-content mod: do it on a **fresh world** (`dst-reset-world`).

## Always
- Keep Master and Caves modoverrides identical. After any manual edit, run `dst sync-mods` so the mod list matches everywhere, then commit (`git add server/config server/docker-compose.yml; git commit`).
- A mod enabled in modoverrides MUST be in `DST_SERVER_MOD_SETUP` (else not downloaded) — `dst sync-mods` guarantees this.
