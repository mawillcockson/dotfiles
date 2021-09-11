load_scripts() {
    if [ -d "${HOME:?""}/.profile.d/" ]; then
        for file in "$HOME/.profile.d"/*.sh; do
            if ! [ -x "$file" ]; then
                continue
            fi

            if ! . "$file"; then
                echo "problem loading script file '$file'"
            fi
        done
    fi
    return 0
}
load_scripts

export EDITOR=vim
export PAGER=less
