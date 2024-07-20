#!/bin/sh
if [ -z "${XDG_CONFIG_HOME:+"set"}" ]; then
    echo "Need XDG_CONFIG_HOME to be set in order to start starship"
else
    if [ "x${COMPUTERNAME}x" != "xINSPIRON15-3521x" ] \
        && [ -z "${NO_STARSHIP+"set"}" ] \
        && command -v starship > /dev/null 2>&1
    then
        export STARSHIP_CACHE="${XDG_CONFIG_HOME}/starship"
        export STARSHIP_CONFIG="${STARSHIP_CACHE}/starship.toml"
        # STARSHIP_LOG="trace"
        eval "$(starship init bash)"
    fi
fi
