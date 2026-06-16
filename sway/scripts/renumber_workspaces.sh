#!/bin/bash

all_workspaces=$(swaymsg -t get_workspaces | jq -r '.[] | .num')
active_workspaces=$(swaymsg -t get_workspaces | jq -r '
  .[] | 
  select(
    .representation != null and 
    .representation != "" and 
    .representation != "H[]" and 
    .representation != "V[]"
  ) | 
  .num' | sort -n)

# If no active window-bearing workspaces are found, exit safely
if [ -z "$active_workspaces" ]; then
    exit 0
fi

target=1
for ws in $active_workspaces; do
    # If a gap exists between the current populated workspace and our sequential target
    if [ "$ws" -ne "$target" ]; then
        if echo "$all_workspaces" | grep -q "^$target"; then
            swaymsg "rename workspace number $target to 100$target"
        fi
        swaymsg "rename workspace number $ws to $target"
    fi
    target=$((target + 1))
done
