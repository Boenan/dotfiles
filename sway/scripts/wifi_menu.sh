#!/usr/bin/env bash
# =============================================================================
# Everforest-themed rofi Wi-Fi menu (NetworkManager via nmcli).
# - Lists nearby networks, connect (prompts for password when needed).
# - Toggle Wi-Fi radio, rescan, open the advanced connection editor.
# - Runs rofi on the native Wayland (layer-shell) backend so it stays crisp on
#   scaled HiDPI outputs, with hover-select + single-click activation (see
#   power_menu.sh). Click-outside-to-dismiss does not work under sway's
#   layer-shell; close with Escape or re-invoke to toggle it shut.
# Invoked by the "network-settings" block click in statusbar.sh.
# =============================================================================

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/wifi_menu.pid"

# ---- Toggle: close an already-open menu -------------------------------------
if [ -f "$PIDFILE" ]; then
    oldpid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
        kill "$oldpid" 2>/dev/null; rm -f "$PIDFILE"; exit 0
    fi
    rm -f "$PIDFILE"
fi

# ---- Icons (nerd font, \u escapes) ------------------------------------------
IC_WIFI=$'\uF1EB'
IC_LOCK=$'\uF023'
IC_CHECK=$'\uF00C'
IC_OFF=$'\uF204'
IC_ON=$'\uF205'
IC_SCAN=$'\uF021'
IC_COG=$'\uF013'

# ---- Everforest rofi theme --------------------------------------------------
theme='
* { bg: #1e2326; fg: #d3c6aa; sel: #2e383c; accent: #a7c080;
    background-color: transparent; text-color: @fg; }
window { location: northeast; anchor: northeast; x-offset: -6px; y-offset: 44px;
    width: 360px; background-color: @bg; border: 2px; border-color: @sel;
    border-radius: 12px; padding: 8px; }
mainbox { spacing: 6px; children: [ inputbar, listview ]; }
inputbar { padding: 8px 12px; background-color: @sel; border-radius: 8px;
    children: [ prompt, entry ]; }
prompt { text-color: @accent; }
entry { placeholder: "Search…"; placeholder-color: @fg; }
listview { lines: 10; spacing: 3px; scrollbar: false; }
element { padding: 8px 12px; border-radius: 8px; children: [ element-text ]; }
element selected { background-color: @accent; text-color: @bg; }
element-text { text-color: inherit; }
'

rofi_menu() {  # $1 = prompt ; reads entries on stdin ; prints selected index
    rofi -dmenu -i -p "$1" -font "Hack Nerd Font 12" -click-to-exit \
         -hover-select -me-select-entry "" -me-accept-entry "MousePrimary" \
         -format 'i' -theme-str "$theme" &
    rpid=$!
    echo "$rpid" > "$PIDFILE"
    wait "$rpid"
    rm -f "$PIDFILE"
}

notify() { command -v notify-send >/dev/null && notify-send -a "Wi-Fi" "$1" "$2"; }

# ---- Build the menu ---------------------------------------------------------
radio=$(nmcli -t -f WIFI radio 2>/dev/null)

labels=()   # display strings
actions=()  # matching action codes (parallel array)

if [ "$radio" = enabled ]; then
    labels+=("$IC_OFF  Disable Wi-Fi"); actions+=("radio-off")
else
    labels+=("$IC_ON  Enable Wi-Fi");   actions+=("radio-on")
fi
labels+=("$IC_SCAN  Rescan");            actions+=("rescan")
labels+=("$IC_COG  Advanced settings");  actions+=("editor")

if [ "$radio" = enabled ]; then
    active_ssid=$(nmcli -t -f IN-USE,SSID device wifi 2>/dev/null | awk -F: '/^\*/{print $2;exit}')
    mapfile -t wlines < <(nmcli -t -f SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)
    declare -A seen
    for line in "${wlines[@]}"; do
        signal=${line%%:*};     rest=${line#*:}
        security=${rest%%:*};   ssid=${rest#*:}
        ssid=${ssid//\\:/:}                 # un-escape colons nmcli -t inserts
        [ -z "$ssid" ] && continue          # skip hidden SSIDs
        [ -n "${seen[$ssid]}" ] && continue # dedupe (keep strongest = first)
        seen[$ssid]=1
        lock=""; sec=0; [ -n "$security" ] && { lock=" $IC_LOCK"; sec=1; }
        mark="";       [ "$ssid" = "$active_ssid" ] && mark=" $IC_CHECK"
        labels+=("$(printf '%s  %s%s%s  %s%%' "$IC_WIFI" "$ssid" "$lock" "$mark" "$signal")")
        actions+=("connect:$sec:$ssid")
    done
fi

idx=$(printf '%s\n' "${labels[@]}" | rofi_menu "Wi-Fi")
[ -z "$idx" ] && exit 0
action=${actions[$idx]}

# ---- Execute ----------------------------------------------------------------
case "$action" in
    radio-off) nmcli radio wifi off; notify "Wi-Fi disabled" ;;
    radio-on)  nmcli radio wifi on;  sleep 1; exec "$0" ;;
    rescan)    nmcli device wifi rescan 2>/dev/null; sleep 2; exec "$0" ;;
    editor)    setsid -f nm-connection-editor >/dev/null 2>&1 ;;
    connect:*)
        rest=${action#connect:}; sec=${rest%%:*}; ssid=${rest#*:}
        if nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$ssid"; then
            # known network -> just bring it up
            if nmcli connection up id "$ssid" >/dev/null 2>&1; then
                notify "Connected" "$ssid"
            else
                notify "Failed to connect" "$ssid"
            fi
        elif [ "$sec" = 1 ]; then
            pw=$(printf '' | rofi -dmenu -password -p "Password" -mesg "Password for $ssid" \
                      -click-to-exit -theme-str "$theme")
            [ -z "$pw" ] && exit 0
            if nmcli device wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then
                notify "Connected" "$ssid"
            else
                notify "Failed to connect" "$ssid"
            fi
        else
            if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
                notify "Connected" "$ssid"
            else
                notify "Failed to connect" "$ssid"
            fi
        fi ;;
esac
