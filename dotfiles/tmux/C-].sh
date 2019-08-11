#!/bin/bash
tmux set-buffer -b systemclip <<< echo "$(xclip -se c -o)"
