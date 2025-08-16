#!/bin/bash

source $CONFIG_DIR/colors.sh

CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
CPU_INFO=$(ps -eo pcpu,user)
CPU_SYS=$(echo "$CPU_INFO" | grep -v $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_USER=$(echo "$CPU_INFO" | grep $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")

CPU_PERCENT="$(echo "$CPU_SYS $CPU_USER" | awk '{printf "%.0f\n", ($1 + $2)*100}')"

# Pick a color by pressure
# Green <= 60, Yellow <= 75, Orange <= 90, Red > 90
if   [ $CPU_PERCENT -le 60 ]; then color=$GREEN  # green-500
elif [ $CPU_PERCENT -le 75 ]; then color=$YELLOW # yellow-500
elif [ $CPU_PERCENT -le 90 ]; then color=$ORANGE # orange-500
else                            color=$RED     # red-500
fi

sketchybar --set $NAME label="$CPU_PERCENT%" label.color=$color
