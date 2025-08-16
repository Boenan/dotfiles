#!/bin/bash

sketchybar --add event aerospace_workspace_change
sketchybar --add event aerospace_monitor_change

for sid in $(aerospace list-workspaces --all); do
    sketchybar --add item space.$sid left \
        --subscribe space.$sid aerospace_workspace_change space_windows_change front_app_switched aerospace_monitor_change \
        --set space.$sid \
        background.color=0x44ffffff \
        background.drawing=off \
        label="| $sid" \
        label.padding_left=10 \
        icon.font="sketchybar-app-font:Regular:16.0" \
        click_script="aerospace workspace $sid" \
        script="$CONFIG_DIR/plugins/aerospace.sh $sid"
done

# # Load Icons on startup
# for mid in $(aerospace list-monitors | cut -c1); do
#   for sid in $(aerospace list-workspaces --monitor $mid --empty no); do
#     apps=$(aerospace list-windows --workspace "$sid" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
#
#     icon_strip=" "
#     if [ "${apps}" != "" ]; then
#       while read -r app; do
#         source $CONFIG_DIR/plugins/icon_map.sh
#         __icon_map "$app"
#         icon_strip+=" $icon_result "
#       done <<<"${apps}"
#     else
#       icon_strip=""
#     fi
#     sketchybar --set space.$sid \
#         icon="$icon_strip" \
#         icon.drawing=on
#   done
# done

