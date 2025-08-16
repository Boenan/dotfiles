#!/bin/bash

sketchybar --add item cpu right \
           --set cpu  update_freq=2 \
                      label.width=40 \
                      label.align=center \
                      icon=􀧓  \
                      script="$PLUGIN_DIR/cpu.sh"
