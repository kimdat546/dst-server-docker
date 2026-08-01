---
name: dst-player-reset
description: Reset or switch a specific player's character on the Don't Starve Together server (e.g. a player can't join / keeps getting disconnected due to a broken or over-the-tag-limit character, or wants to re-pick). Moves their per-user save aside so they re-select a character on next join.
---

# Reset a player's character

Each player's character + inventory is stored per-user at `data/<Shard>/server/general/<Shard>/save/session/<sessionid>/<USERID>/`. Removing that folder → the player lands on character-select next join. Recoverable (move aside, don't delete).

## Find the right player's save
```
SES=$(ls -d data/Master/server/general/Master/save/session/*/ | head -1)
for u in "$SES"*/; do
  [ -d "$u" ] || continue
  latest=$(ls -1 "$u" | grep -E '^[0-9]+$' | sort -n | tail -1)
  char=$(strings "$u/$latest" 2>/dev/null | grep -oE 'prefab="(w[a-z0-9]+|maxwell|willow|webber)"' | head -1)
  echo "$(basename "$u") -> ${char:-?}"
done
```
Match the broken character (e.g. `prefab="wurt"`) → that `<USERID>` is the target.

## Reset it (server must be stopped so the save isn't rewritten)
```
DST_CALLER=claude dst stop   # or: docker compose -p cli --env-file .world.env -f cli/compose.yml stop
mkdir -p data/player-reset-$(date +%Y%m%d)
for S in Master Caves; do
  SES=$(ls -d data/$S/server/general/$S/save/session/*/ | head -1)
  [ -d "$SES<USERID>" ] && mv "$SES<USERID>" data/player-reset-$(date +%Y%m%d)/$S-<USERID>
done
DST_CALLER=claude dst start
```
Player rejoins → character-select.

## Context: the Wurt / 63-tag problem
A character with **>63 network tags** triggers `Error serializing tags … exceeds maximum size of 63` → that player (sometimes the whole party) disconnects. **Wurt** (a merm: many base tags) overflows with this heavy mod set. Resetting the character only helps if they **pick a non-Wurt character** (Wurt re-overflows). There is no clean config lever left to shave Wurt below the limit reliably (most tags are base-merm or functional IA/HoF tags that can't be removed without a fresh, leaner world). See memory `um-lag-crash-options` / `mod-removal-world-content`.

## To restore a player's old character (with their items)
Move their saved folder back from the aside backup into the session (both shards), then `dst restart`. Only safe if the character now fits the tag limit (e.g. after disabling a tag-adding option), otherwise it'll disconnect again.
