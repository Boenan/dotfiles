#!/bin/sh

source $CONFIG_DIR/colors.sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  7[0-7]|100)
    ICON="􀛨"
    color="$GREEN"
  ;;
  [4-6][0-9])
    ICON="􀺸"
    color="$YELLOW"
  ;;
  [2-3][0-9])
    ICON="􀺶"
    color="$ORANGE"
  ;;
  [0-1][0-9])
    ICON="􀛩"
    color="$RED"
  ;;
  *)
    ICON="􀛪"
    color=$WHITE
esac

if [[ "$CHARGING" != "" ]]; then
  ICON="􀢋"
fi


# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" label.color="$color"
