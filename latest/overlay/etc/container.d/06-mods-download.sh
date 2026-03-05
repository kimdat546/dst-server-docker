#!/usr/bin/env bash

# Mod manager for DST dedicated server.
#
# Workshop mods come in two formats:
#   LEGACY (RemoteStorage): distributed as _legacy.bin ZIP files. DST's built-in
#     DownloadPublishedFile API fails for these on dedicated servers. We download via
#     steamcmd, extract, and place in mods/workshop-<id>/. DST finds and loads these
#     as local mods (with proper name from modinfo.lua). These dirs survive DST startup.
#
#   UGC (modern): DST downloads these fine via its own UGC system to ugc_mods/.
#     However DST deliberately deletes any mods/workshop-<id>/ dirs it finds for UGC
#     mods (it prefers its ugc_mods/ path). Without mods/workshop-<id>/modinfo.lua,
#     DST shows "workshop-<id>" as the mod name in the server browser instead of the
#     actual name.
#
# Strategy:
#   - LEGACY mods: steamcmd download + extract + remove from dedicated_server_mods_setup.lua
#   - UGC mods: place only modinfo.lua in mods/workshop-<id>/ as a name stub; keep in
#     dedicated_server_mods_setup.lua so DST downloads the actual mod code via UGC.
#     A background process restores modinfo.lua after DST's startup deletes the dirs,
#     so DST finds the name when it loads mods (~13 s after the deletion).

if [[ "${DST_SKIP_MOD_SETUP}" == "true" ]] || [[ -z "${DST_SERVER_MOD_SETUP}" ]]; then
    true
else

_STEAMCMD_WORKSHOP_DIR="/var/lib/steam/Steam/steamapps/workshop/content/322330"
_STEAMCMD_ACF="/var/lib/steam/Steam/steamapps/workshop/appworkshop_322330.acf"
_LOCAL_MODS_DIR="/usr/share/game/mods"
_MOD_SETUP_FILE="${DST_MOD_SETUP_FILE:-/usr/share/game/mods/dedicated_server_mods_setup.lua}"
_UGC_CONTENT="/usr/share/game/ugc_mods/${DST_SERVER_CLUSTER}/${DST_SHARD_NAME}/content/322330"

IFS=',' read -ra _ALL_MOD_IDS <<< "${DST_SERVER_MOD_SETUP}"

# ── Categorise mods ────────────────────────────────────────────────────────────
# INSTALLED: legacy mods we manage (have .dst_timeupdated) → check for updates
# NEW:       not present anywhere → fresh steamcmd download needed
# (UGC stubs and ugc_mods-only mods are silently skipped)
_MODS_NEW=()
_MODS_INSTALLED=()

for _MOD_ID in "${_ALL_MOD_IDS[@]}"; do
    _MOD_ID="${_MOD_ID// /}"
    [[ -z "${_MOD_ID}" ]] && continue

    if [[ -f "${_LOCAL_MODS_DIR}/workshop-${_MOD_ID}/.dst_timeupdated" ]]; then
        _MODS_INSTALLED+=("${_MOD_ID}")
    elif [[ ! -d "${_LOCAL_MODS_DIR}/workshop-${_MOD_ID}" ]] && \
         [[ ! -d "${_UGC_CONTENT}/${_MOD_ID}" ]]; then
        _MODS_NEW+=("${_MOD_ID}")
    fi
done

# ── Update check via Steam Web API (legacy mods only) ─────────────────────────
_MODS_TO_UPDATE=()

if [[ ${#_MODS_INSTALLED[@]} -gt 0 ]]; then
    _QUERY="itemcount=${#_MODS_INSTALLED[@]}"
    for _i in "${!_MODS_INSTALLED[@]}"; do
        _QUERY="${_QUERY}&publishedfileids[${_i}]=${_MODS_INSTALLED[$_i]}"
    done

    _RESPONSE=$(curl -sf --max-time 20 -X POST \
        "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/" \
        -d "${_QUERY}" 2>/dev/null)

    if [[ -n "${_RESPONSE}" ]]; then
        echo "${_RESPONSE}" \
            | perl -0pe 's/\},\s*\{/}\n{/g' \
            | perl -ne '
                /\"publishedfileid\"\s*:\s*\"(\d+)\"/ and $id = $1;
                /\"time_updated\"\s*:\s*(\d+)/ and $id and do {
                    print "$id $1\n"; $id = "";
                };' \
            | while IFS=' ' read -r _id _t; do
                echo "${_t}" > "/tmp/dst_wtime_${_id}"
              done

        for _MOD_ID in "${_MODS_INSTALLED[@]}"; do
            _STORED_FILE="${_LOCAL_MODS_DIR}/workshop-${_MOD_ID}/.dst_timeupdated"
            _STORED_TIME=$(cat "${_STORED_FILE}" 2>/dev/null || echo "")
            _WORKSHOP_TIME=$(cat "/tmp/dst_wtime_${_MOD_ID}" 2>/dev/null || echo "")

            if [[ -z "${_STORED_TIME}" ]] || \
               { [[ -n "${_WORKSHOP_TIME}" ]] && [[ "${_WORKSHOP_TIME}" != "${_STORED_TIME}" ]]; }; then
                echo "> mod ${_MOD_ID} update detected (local: ${_STORED_TIME:-none}, workshop: ${_WORKSHOP_TIME:-unknown})"
                _MODS_TO_UPDATE+=("${_MOD_ID}")
            fi
            # Keep /tmp/dst_wtime_* alive for fallback in download phase
        done
    else
        echo "> warning: Steam API unreachable, skipping update check for installed mods"
    fi
fi

# ── Download (new + outdated legacy mods) ─────────────────────────────────────
_MODS_TO_DOWNLOAD=("${_MODS_NEW[@]}" "${_MODS_TO_UPDATE[@]}")

_UGC_MOD_SENTINEL=""   # First UGC mod dir created; watched by background process

if [[ ${#_MODS_TO_DOWNLOAD[@]} -gt 0 ]]; then
    echo "> downloading ${#_MODS_TO_DOWNLOAD[@]} mod(s) via steamcmd"

    _STEAMCMD_ARGS="+login anonymous"
    for _MOD_ID in "${_MODS_TO_DOWNLOAD[@]}"; do
        _STEAMCMD_ARGS="${_STEAMCMD_ARGS} +workshop_download_item 322330 ${_MOD_ID}"
    done
    steamcmd ${_STEAMCMD_ARGS} +quit

    for _MOD_ID in "${_MODS_TO_DOWNLOAD[@]}"; do
        _SRC="${_STEAMCMD_WORKSHOP_DIR}/${_MOD_ID}"
        _DST="${_LOCAL_MODS_DIR}/workshop-${_MOD_ID}"

        if [[ ! -d "${_SRC}" ]]; then
            echo "> warning: mod ${_MOD_ID} could not be downloaded, skipping"
            continue
        fi

        # Read timeupdated from steamcmd manifest
        # (grep instead of awk: mawk silently fails the variable-in-regex pattern)
        _NEW_TIME=$(grep -A10 "\"${_MOD_ID}\"" "${_STEAMCMD_ACF}" 2>/dev/null | grep -m1 '"timeupdated"' | tr -dc '0-9')
        if [[ -z "${_NEW_TIME}" ]]; then
            _NEW_TIME=$(cat "/tmp/dst_wtime_${_MOD_ID}" 2>/dev/null || echo "")
        fi

        [[ -d "${_DST}" ]] && rm -rf "${_DST}"
        mkdir -p "${_DST}"

        _EXTRACTED=false
        for _BIN in "${_SRC}"/*_legacy.bin; do
            if [[ -f "${_BIN}" ]]; then
                echo "> extracting legacy zip for mod ${_MOD_ID}"
                unzip -q -o "${_BIN}" -d "${_DST}/" || true
                _EXTRACTED=true
                break
            fi
        done

        if [[ "${_EXTRACTED}" == "true" ]]; then
            # LEGACY mod: full content in mods/workshop-<id>/, DST loads from here
            [[ -n "${_NEW_TIME}" ]] && echo "${_NEW_TIME}" > "${_DST}/.dst_timeupdated"
            echo "> mod ${_MOD_ID} ready as legacy (timeupdated: ${_NEW_TIME:-unknown})"
        else
            # UGC mod: copy only modinfo.lua as a name stub; DST will delete the dir
            # and download the actual mod code via its own UGC system. A background
            # process (below) restores modinfo.lua after DST's deletion so the server
            # browser can display the proper mod name.
            if [[ -f "${_SRC}/modinfo.lua" ]]; then
                cp "${_SRC}/modinfo.lua" "${_DST}/"
            fi
            [[ -z "${_UGC_MOD_SENTINEL}" ]] && _UGC_MOD_SENTINEL="${_DST}"
            echo "> mod ${_MOD_ID} staged as UGC (name stub only)"
        fi
    done

    chown -R steam:steam "${_LOCAL_MODS_DIR}" 2>/dev/null || true
fi

# Clean up Steam API temp files
rm -f /tmp/dst_wtime_*

# ── Remove LEGACY mods from dedicated_server_mods_setup.lua ───────────────────
# Only legacy mods (those with .dst_timeupdated) are removed: DST must not call
# DownloadPublishedFile for them (it always fails). UGC mods remain in the file
# so DST's own UGC system downloads their actual mod code.
if [[ -f "${_MOD_SETUP_FILE}" ]]; then
    for _MOD_ID in "${_ALL_MOD_IDS[@]}"; do
        _MOD_ID="${_MOD_ID// /}"
        if [[ -n "${_MOD_ID}" ]] && \
           [[ -f "${_LOCAL_MODS_DIR}/workshop-${_MOD_ID}/.dst_timeupdated" ]]; then
            sed -i "/ServerModSetup(\"${_MOD_ID}\")/d" "${_MOD_SETUP_FILE}"
        fi
    done
fi

# ── Background: restore modinfo.lua after DST deletes UGC mod dirs ────────────
# DST's ItemQuery phase (~3 s after startup) deletes mods/workshop-<id>/ for any
# UGC-format mod it finds there. We watch for this deletion, then immediately copy
# modinfo.lua back from the steamcmd download. DST reads modinfo.lua when it loads
# mods (~13 s after ItemQuery), giving us a comfortable window to restore it.
if [[ -n "${_UGC_MOD_SENTINEL}" ]]; then
    _BG_STEAMCMD_DIR="${_STEAMCMD_WORKSHOP_DIR}"
    _BG_LOCAL_DIR="${_LOCAL_MODS_DIR}"
    _BG_MOD_IDS="${DST_SERVER_MOD_SETUP}"
    (
        # Wait for DST to delete the sentinel dir (signals ItemQuery has run)
        while [[ -d "${_UGC_MOD_SENTINEL}" ]]; do sleep 1; done

        IFS=',' read -ra _BG_IDS <<< "${_BG_MOD_IDS}"
        for _MOD_ID in "${_BG_IDS[@]}"; do
            _MOD_ID="${_MOD_ID// /}"
            [[ -z "${_MOD_ID}" ]] && continue
            _SRC="${_BG_STEAMCMD_DIR}/${_MOD_ID}/modinfo.lua"
            _DST="${_BG_LOCAL_DIR}/workshop-${_MOD_ID}"
            # Only restore for dirs that were deleted (UGC mods); skip legacy (still present)
            if [[ ! -d "${_DST}" ]] && [[ -f "${_SRC}" ]]; then
                mkdir -p "${_DST}"
                cp "${_SRC}" "${_DST}/"
                chown steam:steam "${_DST}" "${_DST}/modinfo.lua" 2>/dev/null || true
            fi
        done
    ) &
fi

fi

true
