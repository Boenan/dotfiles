#!/bin/bash

sketchybar --add item memory right \
           --set memory update_freq=10 \
                         script="$PLUGIN_DIR/memory.sh" \
                         label.width=175 \
                         label.align=center \
                         icon='󰍛' \
                         icon.font="Hack Nerd Font:Regular:20.0"

