use std/log

export def main [] {
    [
        # it claims this is an unknown option
        #'enable-win32-openssh-support:0:1',
        'enable-putty-support:0:1',
    ] |
    str join (char line_feed) |
    gpgconf --change-options gpg-agent
}
