---
name: dst-reset-world
description: Create a brand-new Don't Starve Together world (fresh map) on this server, keeping the same mods/config. Use for "reset world", "new world", "tạo world mới", "wipe and regenerate". This destroys the current base/world (backed up first).
---

# Reset to a fresh world

Generates a new map; **the current world/base is wiped** (archived to Drive first, recoverable).

## Command
```
DST_CALLER=claude dst reset
```
What it does (already optimized): stop containers **in place** (keeps mod cache) → archive current save to Drive as `<world>.pre-reset.tar.gz` (recoverable) → delete the live Drive save → wipe `data/Master` + `data/Caves` → start → fresh worldgen. **Mods are NOT re-downloaded** (container kept) → fast, only worldgen time.

## Verify
```
docker ps --filter name=dst- --format 'table {{.Names}}\t{{.Status}}'
docker logs --since 12m dst-master-$(cat .dst-current) 2>&1 | grep -E 'is now connected|An error occured during world gen' | tail -3
```
- Watch for `An error occured during world gen … retry` looping (≥6). Causes: `world_size="small"` + heavy mods can fail to place a required setpiece, OR a mod adds a required setpiece that won't fit. If it loops: bump `world_size` in `server/config/*/leveldataoverride.lua` to `"default"`+, or remove the offending mod, then reset again. (`small` CAN work — only loops when a required prefab can't be placed.)

## Notes
- Recovery: the old world is on Drive (`<world>.pre-reset.tar.gz`) — restore with `dst-backup-restore` if needed.
- To reset AND change mods/config in the same go: edit configs first (see `dst-edit-mods`), then `dst reset`.
- Network setting `DST_SHARD_MASTER_IP=127.0.0.1` + `network_mode: host` is correct for this single-VPS master+caves setup — don't change it.
