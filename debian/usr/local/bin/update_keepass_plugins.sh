#!/bin/sh
set -eu

for file in /usr/local/share/sh/*.sh; do
    if ! . "${file}"; then
        printf 'error loading: %s\n' "${file}"
        exit 1
    fi
done

need_commands curl jq

cleanup() {
    info 'running cleanup'

    info "checking if \${TMP} is set"
    if test -n "${TMP:+"set"}"; then
        if ! rm "${TMP}"; then
            warn "cannot remove temporary file -> ${TMP}"
        fi
        info "removed \${TMP} -> ${TMP}"
    fi
    info "checking if \${TMPDIR} is set"
    if test -n "${TMPDIR:+"set"}"; then
        if ! rm -r "${TMPDIR}"; then
            warn "cannot remove temporary directory -> ${TMPDIR}"
        fi
        info "removed \${TMPDIR} -> ${TMPDIR}"
    fi
    trap - EXIT TERM QUIT
}

trap 'cleanup' EXIT TERM QUIT

CACHE_DIR="/var/cache/update_keepass_plugins"
export CACHE_DIR
info "trying to mkdir ${CACHE_DIR}"
mkdir -p "${CACHE_DIR}"
STATE="${CACHE_DIR}/state.json"
export STATE
PLUGIN_DIR="/usr/lib/keepass2/Plugins"
export PLUGIN_DIR
info "trying to mkdir ${PLUGIN_DIR}"
mkdir -p "${PLUGIN_DIR}"
TMP="$(mktemp)"
export TMP
info "using ${TMP} as a temporary file"


check_all_names_unique() {
    if < "${STATE}" jq -e '[.[].name] | (. | length) == (. | unique | length)'; then
        return 0
    else
        error "all the names given to plugin objects in state file ${STATE} must be unique"
        return 1
    fi
}

update_state() {
    if ! test -f "${STATE}"; then
        info 'state cache does not exist, creating a new one'
        default_state > "${STATE}"
    fi

    # NOTE::IMPROVEMENT check if any keys have characters outside a-z
    # Or, change data structure so that it's an array of objects, and that way
    # the keys are integers, and can't have any surprises in terms of shell
    # word splitting

    if ! NUM_PLUGINS="$(< "${STATE}" jq '. | length')"; then
        error "state file isn't in expected shape of array of objects that each describe a plugin -> ${STATE}"
        return 1
    fi
    info "looping over ${NUM_PLUGINS} plugin objects"
    MAX_INDEX="$((NUM_PLUGINS-1))"
    info "plugin array has \$MAX_INDEX of ${MAX_INDEX}"

    info 'refreshing each plugin'\''s cache if it needs to be'
    INDEX='0'
    while test "${INDEX}" -le "${MAX_INDEX}"; do
        # 1 day = 86400 seconds
        # if the cached_at date is newer than 1 day, don't update cache
        if < "${STATE}" jq --argjson 'index' "${INDEX}" -e '.[$index].cached_at > (now - 86400)'; then
            info "cache #${INDEX} is recent enough"
            INDEX="$((INDEX+1))"
            continue
        fi

        info "trying to get the url for where to download cache info from for #${INDEX}"
        < "${STATE}" jq --raw-output --argjson 'index' "${INDEX}" '.[$index].url' > "${TMP}"

        URL="$(cat "${TMP}")"
        info "#${INDEX} has url -> ${URL}"

        info 'downloading current plugin (GitHub) info'
        curl --fail "${URL}" --output "${TMP}"
        if ! < "${TMP}" jq -e '.'; then
            error "${TMP} does not contain valid JSON data"
            cat "${TMP}"
            return 1
        fi

        info "caching downloaded plugin info to state file -> ${STATE}"
        DATA="$(cat "${TMP}")"
        < "${STATE}" jq --indent 2 --argjson 'data' "${DATA}" --argjson 'index' "${INDEX}" '.[$index].data = $data | .[$index].cached_at = now' > "${TMP}"
        cp "${TMP}" "${STATE}"

        INDEX="$((INDEX+1))"
    done
    return 0
}

download_plugin_from_state() {
    if ! test -f "${STATE}"; then
        error "state file missing; should run \`update_state\` -> ${STATE}"
        return 1
    fi

    info 'ensuring every plugin name is unique so that a subsequent plugin file does not overwrite any previous ones'
    check_all_names_unique

    if ! NUM_PLUGINS="$(< "${STATE}" jq '. | length')"; then
        error "state file isn't in expected shape of array of objects that each describe a plugin -> ${STATE}"
        return 1
    fi
    info "looping over ${NUM_PLUGINS} plugin objects"
    MAX_INDEX="$((NUM_PLUGINS-1))"

    info 'checking for new plugins and downloading'
    INDEX='0'
    while test "${INDEX}" -le "${MAX_INDEX}"; do
        if < "${STATE}" jq --argjson 'index' "${INDEX}" -e '.[$index] | (.downloaded_release_id) == (.data.id)'; then
            info "for plugin #${INDEX} downloaded release is the same as current release, no need to update"
            INDEX="$((INDEX+1))"
            continue
        fi

        if ! < "${STATE}" jq --raw-output --argjson 'index' "${INDEX}" '.[$index].data.assets | map(select(.name | endswith(".plgx"))) | first | .browser_download_url' > "${TMP}"; then
            error "plugin data not in expected shape; could not find an asset name ending in .plgx ->"
            < "${STATE}" jq --argjson 'index' "${INDEX}" -C '.[$index].data.assets'
            return 1
        fi
        URL="$(cat "${TMP}")"
        if ! < "${STATE}" jq --raw-output --argjson 'index' "${INDEX}" '.[$index].name' > "${TMP}"; then
            error "name not set for plugin object #${INDEX}"
            return 1
        fi
        NAME="$(cat "${TMP}")"
        FILENAME="${NAME}.plgx"
        info "for plugin #${INDEX}, using filename ${FILENAME}"

        info "downloading plugin from url -> ${URL}"
        curl --fail -L "${URL}" > "${TMP}"

        info 'copying downloaded plugin to cache directory'
        cp "${TMP}" "${CACHE_DIR}/${FILENAME}"

        info 'updating which release id the plugin was downloaded from'
        < "${STATE}" jq --sort-keys --indent 2 --argjson 'index' "${INDEX}" '.[$index].downloaded_release_id = .[$index].data.id' > "${TMP}"

        info 'first copying plugin into correct place, then copying update state file, so that if something fails in between, the plugin will be re-updated'
        cp "${CACHE_DIR}/${FILENAME}" "${PLUGIN_DIR}/${FILENAME}"
        cp "${TMP}" "${STATE}"

        INDEX="$((INDEX+1))"
    done
}

main() {
    update_state
    download_plugin_from_state
}

default_state() {
    jq --null-input --sort-keys --indent 2 '
[
  {
    "name": "keetraytotp",
    "url": "https://api.github.com/repos/KeeTrayTOTP/KeeTrayTOTP/releases/latest",
    "data": {},
    "cached_at": 0,
    "downloaded_release_id": null
  },
  {
    "name": "readablepassphrase",
    "url": "https://api.github.com/repos/ligos/readablepassphrasegenerator/releases/latest",
    "data": {},
    "cached_at": 0,
    "downloaded_release_id": null
  }
]'
}
