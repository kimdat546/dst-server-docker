#!/usr/bin/env bash

# Copy user-managed Lua config files from a bind-mounted directory into the
# shard config dir, bypassing template generation for those files.
#
# Bind-mount your config dir to /etc/dst-config in docker-compose:
#   - ./config/Master:/etc/dst-config:ro   (for master shard)
#   - ./config/Caves:/etc/dst-config:ro    (for caves shard)

_CUSTOM_CONFIG_DIR="/etc/dst-config"

if [[ -d "${_CUSTOM_CONFIG_DIR}" ]]; then
    for _CFG_FILE in leveldataoverride.lua modoverrides.lua; do
        if [[ -f "${_CUSTOM_CONFIG_DIR}/${_CFG_FILE}" ]]; then
            mkdir -p "${DST_SHARD_DIR}"
            cp "${_CUSTOM_CONFIG_DIR}/${_CFG_FILE}" "${DST_SHARD_DIR}/${_CFG_FILE}"
            echo "> using custom ${_CFG_FILE} from bind config"
        fi
    done

    # Tell 20-configs.sh to skip template generation for files we already placed
    [[ -f "${DST_SHARD_DIR}/leveldataoverride.lua" ]] && export DST_SKIP_LEVELDATA_OVERRIDE="true"
    [[ -f "${DST_SHARD_DIR}/modoverrides.lua" ]]     && export DST_SKIP_MOD_OVERRIDES="true"
fi

true
