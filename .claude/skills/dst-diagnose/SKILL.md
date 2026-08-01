---
name: dst-diagnose
description: Diagnose a Don't Starve Together server problem — crash, sudden disconnect, lag/stutter, OOM, mass-disconnect, or "won't start / stuck". Use whenever the user says the server is laggy, crashed, players got disconnected, the VPS froze, or asks to "check the logs / check what's wrong".
---

# Diagnose a DST server problem

Container names: `dst-master-<branch>` / `dst-caves-<branch>` (`branch = cat .dst-current`).

## 1. Triage container + host state
```
docker ps -a --filter name=dst- --format 'table {{.Names}}\t{{.Status}}'
docker inspect dst-master-<b> --format 'Run={{.State.Running}} Exit={{.State.ExitCode}} OOM={{.State.OOMKilled}} Restarts={{.RestartCount}}'
free -m | awk '/Mem|Swap/{print}'
```
- `OOMKilled=true` or caves `Exit (137)` → **out-of-memory** (this 3.8GB VPS is tight; master+caves+~20 mods rely on the 4GB swap). Not a code bug.
- `Exit=0` + `RestartCount=1` + now back up → clean restart (often the Discord `/restart`, or a `c_shutdown`). Not a crash.
- Both `Up`, players dropped → look at logs (below), likely a serialize/tag error, not a crash.

## 2. Find the cause in logs (last few minutes)
Repeated spam = wasted single-thread CPU = **lag**. Find the top offender:
```
docker logs --since 8m dst-master-<b> 2>&1 | sed -E 's/[0-9]{4,}/N/g; s/^\[[0-9:]+\]: //' | sort | uniq -c | sort -rn | head -15
```
Known signatures from past incidents:
| Log signature | Meaning | Fix |
|---|---|---|
| `Stale Component Reference` / `Missing reference: eyeofterror_mini_ally` (hundreds) | Uncompromising `reworked_eyes` leaks refs → CPU lag | set `reworked_eyes=false` (see dst-edit-mods) |
| `bearger_boulder.lua:86 … 'inst' (a nil value)` → `Error during game initialization` | UM `harder_bearger` × IA physics crash on Bearger boulder hit | set `harder_bearger=false` |
| `Error serializing tags for entity wurt[...] - 64 tags; exceeds maximum size of 63` | character has >63 net tags → that player (or party) disconnects | see dst-player-reset; Wurt overflows with this mod set |
| `random_farmplot` / `Could not find an asset … .xml` at modmain | a removed/broken mod | re-add the mod, or remove cleanly on a fresh world |
| `An error occured during world gen … retry` looping (≥6) | worldgen can't place a required setpiece (often `world_size="small"`) | bump world_size, or remove the offending setpiece mod |
| `MOD ERROR: workshop-<id>` | a specific mod crashing | identify/disable that mod |

CPU check (DST sim is ~single-thread; ~100% of one core = the lag, NOT RAM):
```
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' dst-master-<b> dst-caves-<b>
vmstat 1 3   # si/so≈0 & wa=0 ⇒ swap is NOT thrashing ⇒ adding swap won't help
```

## Key facts (do not relearn the hard way)
- **Lag = single-thread CPU / mod overhead, not RAM.** Never tell the user "add swap" to fix lag.
- A bare `docker restart` sometimes appears not to restart (StartedAt unchanged) — prefer `dst restart` / `compose restart`.
- Memories for this project live in `.claude/projects/-root-dst-server-docker/memory/`.
