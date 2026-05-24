#!/bin/bash

# Target your ThinkPad keyboard device
DEVICE="at-translated-set-2-keyboard"

# Check what the current layout is set to dynamically
CURRENT=$(hyprctl devices -j | jq -r --arg dev "$DEVICE" '.keyboards[] | select(.name == $dev) | .active_keymap')

if [[ "$CURRENT" == *"English"* ]]; then
    # Inject Swedish layout instantly
    hyprctl keyword device["$DEVICE"]:kb_layout se
else
    # Revert back to US layout safely
    hyprctl keyword device["$DEVICE"]:kb_layout us
fi
