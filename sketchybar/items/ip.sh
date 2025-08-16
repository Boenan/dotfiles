#!/bin/bash

sketchybar --add item ipitem_text right \
  --set ipitem_text \
    icon.font="Hack Nerd Font:Bold:15.0" \
    label.font="Hack Nerd Font:Regular:15.0" \
    update_freq=5 \
    label.align=center \
    icon.align=center \
    icon.y_offset=2 \
    script="$PLUGIN_DIR/ip.sh"

