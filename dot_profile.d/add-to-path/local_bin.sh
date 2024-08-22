# Created by `pipx` on 2022-08-14 17:26:29
# modified by me
if [ "$(uname -o)" = "Android" ]; then
    printf '%s:' '/data/data/com.termux/files/home/.local/bin'
fi
printf '%s' "${HOME}/.local/bin"
