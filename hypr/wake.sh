#!/bin/bash
# Turn on all monitors
hyprctl dispatch dpms on

# Check if the laptop lid is closed. If it is, immediately disable eDP-1 again.
if grep -q "closed" /proc/acpi/button/lid/*/state; then
    hyprctl keyword monitor "eDP-1, disable"
fi
