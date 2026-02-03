# https://github.com/akinomyoga/ble.sh/wiki/Vi-%28Vim%29-editing-mode
set -o vi
bleopt complete_auto_delay=500
bleopt complete_auto_menu=500

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
