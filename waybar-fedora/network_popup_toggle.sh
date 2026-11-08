#!/usr/bin/env bash
# =============================================================================
# Controls the bar popup: network_popup_toggle.sh [network|calendar|power|bluetooth]
# The waybar modules run this script. The popup process normally runs already,
# so one signal is sufficient. The pattern includes the interpreter so an
# editor with the file open is safe.
# =============================================================================

case "${1:-network}" in
    calendar) sig=USR2; show=--show-calendar ;;
    power)    sig=HUP;  show=--show-power ;;
    bluetooth) sig=WINCH; show=--show-bluetooth ;;
    *)        sig=USR1; show=--show ;;
esac

pkill -"$sig" -f '^/usr/bin/python3 .*/network_popup[.]py' && exit 0
setsid -f "$HOME/.config/waybar/network_popup.py" "$show" >/dev/null 2>&1
