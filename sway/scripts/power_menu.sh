#!/usr/bin/env bash
# =============================================================================
# Everforest-themed rofi power dropdown (top-right, under the power button).
#
# Runs rofi on its X11 (XWayland) backend on purpose: rofi's "click outside to
# close" relies on a global pointer grab, which works under X11 but not the
# Wayland layer-shell backend. XWayland renders crisply here and gives us real
# click-outside dismissal.
#
# Also toggles: invoking it again while open closes it (pidfile guard), so a
# second click on the swaybar power button hides the menu.
# =============================================================================

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/power_menu.pid"

# ---- Toggle: if a menu is already open, close it and exit --------------------
if [ -f "$PIDFILE" ]; then
    oldpid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
        kill "$oldpid" 2>/dev/null
        rm -f "$PIDFILE"
        exit 0
    fi
    rm -f "$PIDFILE"   # stale pidfile
fi

# ---- Menu entries: "<icon>  <label>" (icons via \u escapes so bytes survive) --
lock=$(printf '\uF023  Lock')
logout=$(printf '\uF08B  Logout')
suspend=$(printf '\uF186  Suspend')
hibernate=$(printf '\uF2DC  Hibernate')
reboot=$(printf '\uF021  Reboot')
shutdown=$(printf '\uF011  Shutdown')

# ---- Everforest Dark Hard rofi theme ----------------------------------------
theme='
* {
    bg:     #1e2326;
    fg:     #d3c6aa;
    sel:    #2e383c;
    accent: #a7c080;
    background-color: transparent;
    text-color:      @fg;
}
window {
    location:         northeast;
    anchor:           northeast;
    x-offset:         -6px;
    y-offset: 44px;
    width:            220px;
    background-color: @bg;
    border:           2px;
    border-color:     @sel;
    border-radius:    12px;
    padding:          8px;
}
mainbox { spacing: 6px; children: [ inputbar, listview ]; }
inputbar {
    padding:          8px 12px;
    background-color: @sel;
    border-radius:    8px;
    children:         [ prompt ];
}
prompt { text-color: @accent; }
listview { lines: 6; spacing: 3px; scrollbar: false; }
element {
    padding:       8px 12px;
    border-radius: 8px;
    children:      [ element-text ];
}
element selected {
    background-color: @accent;
    text-color:       @bg;
}
element-text { text-color: inherit; }
'

# ---- Launch on the X11 backend (backgrounded so we can record rofi's PID) -----
out=$(mktemp)
WAYLAND_DISPLAY= DISPLAY="${DISPLAY:-:0}" \
    rofi -dmenu -i -p "Power" -font "Hack Nerd Font 12" -click-to-exit -theme-str "$theme" \
    < <(printf '%s\n' "$lock" "$logout" "$suspend" "$hibernate" "$reboot" "$shutdown") \
    > "$out" 2>/dev/null &
rpid=$!
echo "$rpid" > "$PIDFILE"
wait "$rpid"
rm -f "$PIDFILE"
chosen=$(cat "$out"); rm -f "$out"

case "$chosen" in
    *Lock)      swaylock -f -c 000000 ;;
    *Logout)    swaymsg exit ;;
    *Suspend)   systemctl suspend ;;
    *Hibernate) systemctl hibernate ;;
    *Reboot)    systemctl reboot ;;
    *Shutdown)  systemctl poweroff ;;
esac
