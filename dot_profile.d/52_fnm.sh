if command -v fnm 2>&1 >/dev/null; then
    if ! FNM_INIT="$(fnm env --shell bash)"; then
        echo 'problem generating fnm env'
    else
        if ! eval "${FNM_INIT}"; then
            echo 'problem loading fnm environment'
        fi
    fi
fi
