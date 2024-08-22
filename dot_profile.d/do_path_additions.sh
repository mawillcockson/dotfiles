if ! command -v path_additions >/dev/null 2>&1; then
    echo "path_additions command not loaded!"
else
    if ! path_additions; then
        echo "problem with path_additions"
    fi
fi
