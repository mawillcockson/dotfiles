if [ -z "${ALREADY_SOURCED_USER_PROFILE+"set"}" ] && [ -r ~/.profile ] ; then
    if ! . ~/.profile; then
        echo "problem with ~/.profile"
    fi
fi
