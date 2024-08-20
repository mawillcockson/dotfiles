HOME="${HOME:?"\$HOME not set!"}"
export HOME

# from:
# https://github.com/mawillcockson/dotfiles/blob/d9cd2ef8ca9293c8f7b86de8c5b23246135b6f5c/dotfiles/.profile
if [ -d /etc/profile.d ]; then
    for file in /etc/profile.d/*.sh; do
        if ! . "$file"; then
            printf '%s did not load correctly\n' "$file"
        fi
    done
fi

if [ -d "${HOME}/.profile.d" ]; then
    for file in "${HOME}/.profile.d"/.*sh; do
        if ! . "$file"; then
            printf '%s did not load correctly\n' "$file"
        fi
    done
fi
