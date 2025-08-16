#!/usr/bin/env bash
# ~/.config/sketchybar/plugins/aerospace.sh
# Called as: script "$CONFIG_DIR/plugins/aerospace.sh" <workspace-id>

source "$CONFIG_DIR/colors.sh"
ws="$1"

# Fallback to a live query if the trigger didn't provide FOCUSED_WORKSPACE
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

# Build icon strip for this workspace
apps="$(aerospace list-windows --workspace "$ws" 2>/dev/null \
       | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}' \
       | sort -u)"

icon_strip=""
if [ -n "$apps" ]; then
  while IFS= read -r app; do
    [ -z "$app" ] && continue
    source "$CONFIG_DIR/plugins/icon_map.sh"
    __icon_map "$app"        # -> sets $icon_result
    icon_strip+=" $icon_result "
  done <<< "$apps"
fi

# Prepare one atomic --set call for this specific item only
args=(--set "space.$ws")

if [ -n "$icon_strip" ]; then
  args+=("icon=$icon_strip" "icon.drawing=on" )
else
  args+=("icon=" "icon.drawing=off")
fi

if [ "$ws" = "$focused" ]; then
  args+=( "background.drawing=on" "background.color=$ACCENT_COLOR" "icon.color=$BAR_COLOR" "label.color=$BAR_COLOR" )
else
  args+=("background.drawing=off" "label.color=$WHITE" "icon.color=$WHITE")
fi

sketchybar "${args[@]}"

