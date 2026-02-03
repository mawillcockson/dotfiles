### Use Vi-style line editing
# https://github.com/akinomyoga/ble.sh/wiki/Vi-%28Vim%29-editing-mode
set -o vi

### delay autocompletion
bleopt complete_auto_delay=500
bleopt complete_auto_menu=500

### C-c to cancel/discard line
# The default mapping of C-c is vi_imap/normal-mode-without-insert-leave (in vi_imap), vi-command/cancel (in vi_nmap). If you instead want to discard the current line and go to the next line, you can bind C-c to 'discard-line':
# https://github.com/akinomyoga/ble.sh/wiki/Vi-%28Vim%29-editing-mode#normalinsert-mode-c-c-cancel--discard-line
ble-bind -m vi_imap -f 'C-c' discard-line

### C-r in insert mode searches history
# atuin overwrites C-r, and this ensures if atuin doesn't work, history search still does
ble-bind -m vi_imap -f 'C-r' history-isearch-backward

# https://github.com/akinomyoga/ble.sh/wiki/Performance#wsl2-mnt
# WSL2's /mnt contains bridges to the file systems in the Windows subsystem,
# which internally seems to cause a round-trip communication for every single
# syscall and is thus extremely slow when a directory contains many file
# entries.
# NOTE::IMPROVEMENT enable inside WSL2 only
#ble/path#remove-glob PATH '/mnt/*'

### These may be needed on slower systems
# timeouts and limits for the highlighting.
bleopt highlight_timeout_async=5000
bleopt highlight_timeout_sync=50
bleopt highlight_eval_word_limit=200

# Note: This internally sets "bind 'set colored-stats off'".
bleopt complete_menu_color=off

# Note: This internally sets "bind 'set colored-completion-prefix off'".
bleopt complete_menu_color_match=on
