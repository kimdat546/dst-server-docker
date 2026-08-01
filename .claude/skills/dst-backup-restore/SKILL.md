---
name: dst-backup-restore
description: Back up the Don't Starve Together world to Google Drive, or recover a world after damage/loss (lost items, lost base, or a bad save). Use for "backup world", "push to drive", "restore world", "I lost my items/base", "roll back to a good save".
---

# Backup & restore the world

Saves sync to Google Drive via rclone (`dst-storage:dst-worlds/<world>.tar.gz`). Local snapshots live under `data/<Shard>/server/general/<Shard>/save/session/<id>/` (numbered files = autosaves).

## Back up now (to Drive)
```
DST_CALLER=claude dst push          # uploads current data/ → <world>.tar.gz (prev kept as .bak)
```
`dst stop` also pushes (graceful) before clearing. `dst list` shows cloud saves.

## Restore from Drive
```
DST_CALLER=claude dst pull <world>  # downloads & extracts (swaps only on success)
DST_CALLER=claude dst start
```
Drive keeps: `<world>.tar.gz` (live), `<world>.bak.tar.gz` (previous push), `<world>.pre-reset.tar.gz` (last reset).

## Recover a DAMAGED world from a local snapshot
If items/buildings vanished (e.g. a world-content mod was removed → entities stripped), roll the WORLD back to the last intact snapshot. **Damaged snapshots are smaller** (fewer entities) — use file size to find the good one:
```
S=data/Master/server/general/Master/save/session/*/
for n in $(ls -1 $S | grep -E '^[0-9]+$' | sort -n); do printf '%s  %8s  %s\n' "$n" "$(stat -c %s $S$n)" "$(stat -c %y $S$n|cut -d. -f1)"; done
```
A sudden size drop (e.g. 5.2MB → 2.8MB) marks the damage point — the last full-size snapshot before it is the intact one. Then:
1. Make sure the mod that was wrongly removed is back in modoverrides (`dst sync-mods`).
2. Stop: `DST_CALLER=claude dst stop` (or `compose stop`).
3. Move the damaged (newer, smaller) snapshots aside on BOTH shards (into `data/.aside-<ts>/`) so the intact one is latest.
4. `DST_CALLER=claude dst start` → loads the intact world with the mod restored.

## Notes
- Always back up (`dst push`) BEFORE destructive ops (reset, removing a mod, big config changes).
- Everything is recoverable: moved-aside snapshots stay under `data/.*aside*` and Drive keeps `.bak`/`.pre-reset`.
- Past incident: removing Heap of Foods stripped the world; recovered by rolling back to the pre-removal 5.2MB snapshot after re-adding the mod.
