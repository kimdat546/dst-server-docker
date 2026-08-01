---
name: dst-rollback
description: Roll the Don't Starve Together world back in time to an earlier autosave (undo recent progress / "reset the current day" / go back N days), keeping the same map, mods and base. Use for "rollback", "reset lại ngày hiện tại", "lùi N ngày", "undo what happened".
---

# Roll the world back N autosaves (~N in-game days)

The server autosaves roughly once per in-game day (default day = ~8 min). Rolling back N snapshots ≈ N days. Map/base/mods are kept — only time moves back.

> Why not `c_rollback`? That console command can't be sent from the host (the container runs with stdin = /dev/null). This does the file-level equivalent.

## Command
```
DST_CALLER=claude dst rollback 1     # back 1 snapshot (~1 day); use N for more
```
What it does: `compose kill` (no save-over so the current state isn't written), moves the latest N world snapshots aside (both shards, into `data/.rollback-aside-<ts>/` — **recoverable**), then `compose start` (in place, mods cached → fast). Both shards stay in sync (same snapshot numbers).

## Verify
```
docker ps --filter name=dst- --format 'table {{.Names}}\t{{.Status}}'
docker logs --since 6m dst-master-$(cat .dst-current) 2>&1 | grep 'is now connected' | tail -1
```

## Notes
- It is **NOT** a reset and does **NOT** change the day to 1 — to start a brand-new map use `dst-reset-world`.
- To undo a rollback or go back further, the moved snapshots are in `data/.rollback-aside-*` (recoverable). Going back more = `dst rollback <bigger N>`.
- Player carried-inventory lives in per-user saves (separate numbering); a world rollback restores world entities (chests/buildings/ground items), player inventory may be slightly newer — usually fine.
