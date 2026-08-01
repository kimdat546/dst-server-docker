---
name: dst-translate-mod
description: Make a Workshop mod's in-game text readable (switch its language to English, or translate its strings to Vietnamese) on the DST server. Use when a mod is in Chinese/another language and the user wants English or Vietnamese.
---

# Translate / re-language a DST mod

Mods live (per shard) in the container at `/var/lib/steam/Steam/steamapps/workshop/content/322330/<id>/`. Inspect via `docker exec dst-master-<branch> sh -c '…'`.

## Step 1 — Check for a built-in language option (easiest, persistent)
Many Chinese mods have a language config (`lan`/`locale`/`LANGUAGE`/`CH_LANG`):
```
docker exec dst-master-<b> sh -c 'grep -inE "name *=|label *=|data *=" /var/lib/steam/Steam/steamapps/workshop/content/322330/<id>/modinfo.lua | grep -iB1 -A6 language'
```
If it offers `data="en"` (English): add it to the mod's config in **both** `server/config/{Master,Caves}/modoverrides.lua`, e.g. `lan="en"`, then `dst restart`. (Note: if the option is inside a `--[[ ]]` comment block in modinfo it may be inactive — try it; if the UI doesn't change, the mod ignores the config and you must translate strings.)
- Mod `3288149713` (童话世界 Fairy Tales): has `lan` (cn/en, default cn) — **try `lan="en"` first** for English.

## Step 2 — Translate strings to Vietnamese (no `vi` option → real work)
Strings live in files like `scripts/AddStrings_ch.lua` (Chinese) / an English equivalent, or inline `STRINGS.x = "…"`.
1. Extract the strings: `docker exec … cat …/scripts/AddStrings_*.lua` — these are `STRINGS.<KEY> = "中文"` (or a table). Prefer translating from the **English** strings if present (better than from Chinese).
2. Translate the values to Vietnamese (keep keys/format specifiers like `%s` intact).
3. **Apply persistently** — direct edits to the mod files are wiped on mod update / container recreate. Robust options:
   - Inject via `DST_MOD_OVERRIDES_RAW` / a small **companion mod** added to the mod set that overrides `STRINGS` in its `modmain.lua` (survives recreate because it's a tracked mod).
   - Or (quick, non-persistent) edit the mod's strings file in the container + `dst restart`, and re-apply after any mod update.
4. Restart to apply (`dst restart`), verify in-game.

## Caveats
- Machine translation quality varies; offer the user a review pass for important strings.
- Adding a companion translation mod adds 1 to the mod count (watch the per-character 63-tag limit if it tags players — a strings-only mod usually doesn't).
- Keep Master and Caves modoverrides identical; run `dst sync-mods` after any mod-list change.
