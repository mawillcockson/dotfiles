## PATH modification ##
# This expects a directory ~/.profile.d/add-to-path/ to be present.
# Each file in this directory should have an add_to_path() function defined
# that, when called, prints out the string to add to the PATH environment
# variable.
#
# For example:
#
# add_to_path() {
#     echo "$HOME/apps/custom_app/bin:$HOME/.custom_app/bin"
#     return 0
# }
#
# Each component in the string will be checked to see if it points to a
# directory, and if it's already defined in PATH.
#
# help from:
# https://stackoverflow.com/a/15155077
# https://stackoverflow.com/a/29949759
# https://stackoverflow.com/a/11655875
path_additions () {
    local - ADD_TO_PATH_DIR ADDITION NEWPATH component file add_to_path
    set -eu
    ADD_TO_PATH_DIR="$HOME/.profile.d/add-to-path"
    export ADD_TO_PATH_DIR

    if [ -d "$ADD_TO_PATH_DIR" ]; then
        for file in "$ADD_TO_PATH_DIR"/* ; do
            unset -f add_to_path > /dev/null 2>&1 || true
            set +e
            . "$file"
            if [ "$?" -ne 0 ]; then
                echo "there was a problem with the file \"${file}\""
                continue
            fi
            set -e
            if ! { command -v add_to_path ; } > /dev/null 2>&1; then
                printf "add_to_path() function not defined in \"${file}\""
                continue
            fi
            set +e
            ADDITION="$(add_to_path)"
            if [ "$?" -ne 0 ] || [ -z "${ADDITION:-}" ] ; then
                set -e
                printf "problem with add_to_path() function in \"${file}\""
                continue
            fi
            set -e
            export ADDITION
            NEWPATH="$(
                IFS=:
                for component in $ADDITION; do
                    if [ -z "$component" ]; then
                        continue
                    fi
                    # # if the shortest suffix matching the pattern '/'
                    # # is removed, is the string the same?
                    # # -> does the string end in a / character?
                    # if [ "${component%'/'}" != "$component" ]; then
                    # if the longest prefix ending in / is removed, is the string empty?
                    # -> does the string end in a / character?
                    if [ -z "${component##*/}" ]; then
                        component="${component%'/'}"
                    fi
                    if [ -d "$component" ] && [ -n "${PATH##*"${component}"}" ] && [ -n "${PATH##*"${component}":*}" ]; then
                        PATH="$PATH:$component"
                    fi
                done
                printf '%s' "$PATH"
            )"
            if [ "$?" -ne 0 ]; then
                echo "problem parsing path additions from \"${file}\""
                continue
            fi
            PATH="$NEWPATH"
            export PATH
        done
    fi
    # NOTE:BUG Why does zsh close immediately after startup without this???
    set +e
    return 0
}
path_additions
