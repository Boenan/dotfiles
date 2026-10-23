#!/usr/bin/env bash
# Lid closed: disable the laptop screen only if another output is active.
# Without this check, sway turns off the only screen when no monitor is connected.
if swaymsg -t get_outputs -r | jq -e '[.[] | select(.name != "eDP-1" and .active)] | length > 0' >/dev/null; then
    swaymsg output eDP-1 disable
fi
