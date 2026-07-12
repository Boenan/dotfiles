#!/usr/bin/env bash
# =============================================================================
# swaybar status_command  --  i3bar protocol generator
# Themed to match the Everforest Dark Hard waybar config.
# Modules (left -> right order matches waybar's modules-right):
#   pulseaudio  network  power-profile  cpu  memory  temperature  battery  clock  power
# =============================================================================

# ---- Everforest Dark Hard palette ------------------------------------------
BG="#1e2326"; FG="#d3c6aa"; RED="#e67e80"; ORANGE="#e69875"; YELLOW="#dbbc7f"
GREEN="#a7c080"; AQUA="#83c092"; BLUE="#7fbbb3"; PURPLE="#d699b6"; GREY="#859289"

# ---- Nerd Font icons --------------------------------------------------------
# Codepoints from the waybar config, except temp/power which used glyphs that
# Nerd Fonts v3 relocated (U+F76B/F769) or that need a fallback font (U+23FB) --
# swapped for the stable FontAwesome thermometer + power-off glyphs.
# Each icon is wrapped in a pango <span> so it renders larger than the text
# (single quotes in the attribute keep the JSON valid without escaping).
_i() { printf "<span size='small'>%s</span>" "$1"; }
I_CPU=$(_i $'\uF2DB')                              # microchip
I_MEM=$(_i $'\uF0C9')                              # bars
I_TEMP=("$(_i $'\uF2C7')" "$(_i $'\uF2C9')" "$(_i $'\uF2CB')")  # empty/half/full
I_BAT_CHARGE=$(_i $'\uF0E7')                       # bolt (charging)
I_BAT=("$(_i $'\uF244')" "$(_i $'\uF243')" "$(_i $'\uF242')" "$(_i $'\uF241')" "$(_i $'\uF240')")
I_PP_PERF=$(_i $'\uF0E7')                          # bolt
I_PP_BAL=$(_i $'\uF24E')                           # balance-scale
I_PP_SAVE=$(_i $'\uF06C')                          # leaf
I_ETH=$(_i $'\uF0E8')
I_VOL=("$(_i $'\uF026')" "$(_i $'\uF027')" "$(_i $'\uF028')")   # off/low/high
I_MUTE=$(_i $'\uF466')
I_MIC=$(_i $'\uF130')
I_NETCOG=$(_i $'\uF013')                           # cog (network settings)
I_WIFI=$(_i $'\uF1EB')
I_POWER=$(_i $'\uF011')                            # power-off

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CLOCK_ALT="$STATE_DIR/swaybar_clock_alt"
NET_ALT="$STATE_DIR/swaybar_net_alt"

# PID of the main shell; helpers signal it (SIGUSR1) to force an instant redraw
MAIN_PID=$$

# ---- Click handling (reads i3bar click events from stdin) -------------------
handle_clicks() {
    # Read from fd 3 (a dup of the script's real stdin). A bare `&` background
    # job in a non-interactive shell gets stdin redirected to /dev/null, so we
    # must read the swaybar click stream through an explicitly-inherited fd.
    while read -r line <&3; do
        [ -n "$SWAYBAR_DEBUG" ] && printf '%s\n' "$line" >>"$STATE_DIR/swaybar_clicks.log"
        # swaybar emits pretty-printed JSON with spaces after colons
        name=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$line")
        button=$(sed -n 's/.*"button"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' <<<"$line")
        case "$name" in
            pulseaudio)
                if [ "$button" = "3" ]; then
                    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
                else
                    setsid -f pavucontrol >/dev/null 2>&1 || true
                fi ;;
            network)
                [ -e "$NET_ALT" ] && rm -f "$NET_ALT" || touch "$NET_ALT" ;;
            network-settings)
                setsid -f "$HOME/.config/sway/scripts/wifi_menu.sh" >/dev/null 2>&1 || true ;;
            power-profile)
                cur=$(busctl --system get-property net.hadess.PowerProfiles \
                    /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null \
                    | awk -F'"' '{print $2}')
                case "$cur" in
                    power-saver) next=balanced ;;
                    balanced)    next=performance ;;
                    performance) next=power-saver ;;
                    *)           next=balanced ;;
                esac
                busctl --system set-property net.hadess.PowerProfiles \
                    /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s "$next" \
                    2>/dev/null || true ;;
            clock)
                [ -e "$CLOCK_ALT" ] && rm -f "$CLOCK_ALT" || touch "$CLOCK_ALT" ;;
            power)
                setsid -f "$HOME/.config/sway/scripts/power_menu.sh" >/dev/null 2>&1 || true ;;
        esac
        # redraw immediately after any click
        kill -USR1 "$MAIN_PID" 2>/dev/null
    done
}
exec 3<&0            # preserve the real stdin (swaybar click stream) as fd 3
handle_clicks &

# ---- Block helper -----------------------------------------------------------
# add_block <name> <full_text> <color> [background]
blocks=()
add_block() {
    local name="$1" text="$2" color="$3" bg="$4" json
    json="{\"name\":\"$name\",\"full_text\":\"$text\",\"color\":\"$color\""
    [ -n "$bg" ] && json="$json,\"background\":\"$bg\""
    json="$json,\"markup\":\"pango\",\"separator\":false,\"separator_block_width\":5}"
    blocks+=("$json")
}

# ---- Module readers ---------------------------------------------------------
mod_pulseaudio() {
    local v vol icon mic micv micextra=""
    v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return
    [ -z "$v" ] && return
    vol=$(awk '{printf "%d", $2*100}' <<<"$v")
    if [[ "$v" == *MUTED* ]]; then
        add_block pulseaudio " $I_MUTE $vol% " "$GREY"; return
    fi
    if   [ "$vol" -lt 34 ]; then icon="${I_VOL[0]}"
    elif [ "$vol" -lt 67 ]; then icon="${I_VOL[1]}"
    else                         icon="${I_VOL[2]}"; fi

    mic=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
    if [ -n "$mic" ] && [[ "$mic" != *MUTED* ]]; then
        micv=$(awk '{printf "%d", $2*100}' <<<"$mic")
        micextra="  $micv% $I_MIC"
    fi
    add_block pulseaudio " $vol% $icon$micextra " "$YELLOW"
}

mod_network() {
    local line dev ssid sig eth ip
    # DEVICE:TYPE:STATE:CONNECTION  (SSID = CONNECTION, may contain spaces)
    line=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null \
        | awk -F: '$2=="wifi"&&$3=="connected"{print;exit}')
    if [ -n "$line" ]; then
        dev=$(cut -d: -f1 <<<"$line")
        ssid=$(cut -d: -f4- <<<"$line")
        # escape pango markup metacharacters in the (dynamic) SSID
        ssid=${ssid//&/&amp;}; ssid=${ssid//</&lt;}; ssid=${ssid//>/&gt;}
        if [ -e "$NET_ALT" ]; then
            ip=$(ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4; exit}')
            add_block network " $dev: ${ip:-no IP} $I_WIFI " "$BLUE"
        else
            sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk -F: '/^\*/{print $2;exit}')
            add_block network " $ssid (${sig:-?}%) $I_WIFI " "$BLUE"
        fi
        return
    fi
    eth=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$2=="ethernet"&&$3=="connected"{print $1;exit}')
    if [ -n "$eth" ]; then
        if [ -e "$NET_ALT" ]; then
            ip=$(ip -4 -o addr show dev "$eth" 2>/dev/null | awk '{print $4; exit}')
            add_block network " $eth: ${ip:-no IP} $I_ETH " "$BLUE"
        else
            add_block network " $eth $I_ETH " "$BLUE"
        fi
        return
    fi
    add_block network " Disconnected ⚠ " "$RED"
}

mod_networksettings() { add_block network-settings " $I_NETCOG " "$AQUA"; }

mod_powerprofile() {
    local prof icon color
    prof=$(busctl --system get-property net.hadess.PowerProfiles \
        /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null \
        | awk -F'"' '{print $2}')
    [ -z "$prof" ] && return
    case "$prof" in
        performance) icon="$I_PP_PERF"; color="$RED" ;;
        power-saver) icon="$I_PP_SAVE"; color="$GREEN" ;;
        *)           icon="$I_PP_BAL";  color="$BLUE" ;;
    esac
    add_block power-profile " $icon " "$color"
}

# CPU needs deltas across iterations
read_cpu() { awk '/^cpu /{idle=$5+$6;t=0;for(i=2;i<=NF;i++)t+=$i;print t,idle;exit}' /proc/stat; }
PREV_TOTAL=0; PREV_IDLE=0
mod_cpu() {
    local total idle dt di usage
    read total idle < <(read_cpu)
    dt=$((total-PREV_TOTAL)); di=$((idle-PREV_IDLE))
    PREV_TOTAL=$total; PREV_IDLE=$idle
    [ "$dt" -le 0 ] && dt=1
    usage=$(( (100*(dt-di))/dt ))
    add_block cpu " $usage% $I_CPU " "$RED"
}

mod_memory() {
    local mem
    mem=$(awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{printf "%d",(t-a)*100/t}' /proc/meminfo)
    add_block memory " $mem% $I_MEM " "$PURPLE"
}

mod_temperature() {
    local raw="" h temp icon
    for h in /sys/class/hwmon/hwmon*; do
        if [ "$(cat "$h/name" 2>/dev/null)" = "k10temp" ]; then
            raw=$(cat "$h/temp1_input" 2>/dev/null); break
        fi
    done
    [ -z "$raw" ] && raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    [ -z "$raw" ] && return
    temp=$((raw/1000))
    if   [ "$temp" -lt 50 ]; then icon="${I_TEMP[0]}"
    elif [ "$temp" -lt 70 ]; then icon="${I_TEMP[1]}"
    else                          icon="${I_TEMP[2]}"; fi
    if [ "$temp" -ge 80 ]; then
        add_block temperature " ${temp}°C $icon " "$BG" "$RED"
    else
        add_block temperature " ${temp}°C $icon " "$ORANGE"
    fi
}

mod_battery() {
    local cap status icon color bg=""
    cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null) || return
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
        add_block battery " $cap% $I_BAT_CHARGE " "$AQUA"; return
    fi
    if   [ "$cap" -le 20 ]; then icon="${I_BAT[0]}"
    elif [ "$cap" -le 40 ]; then icon="${I_BAT[1]}"
    elif [ "$cap" -le 60 ]; then icon="${I_BAT[2]}"
    elif [ "$cap" -le 80 ]; then icon="${I_BAT[3]}"
    else                         icon="${I_BAT[4]}"; fi
    if [ "$cap" -le 15 ]; then color="$BG"; bg="$RED"; else color="$GREEN"; fi
    add_block battery " $cap% $icon " "$color" "$bg"
}

mod_clock() {
    if [ -e "$CLOCK_ALT" ]; then
        add_block clock " $(date '+%Y-%m-%d') " "$FG"
    else
        add_block clock " $(date '+%H:%M') " "$FG"
    fi
}

mod_power() { add_block power " $I_POWER " "$RED"; }

# ---- Main loop --------------------------------------------------------------
# SIGUSR1 interrupts the sleep so we redraw instantly on demand.
SLEEP_PID=""
trap 'kill "$SLEEP_PID" 2>/dev/null' USR1

# Push a redraw whenever PipeWire/PulseAudio state changes (volume, mute, etc.)
( pactl subscribe 2>/dev/null | while read -r _ev; do
    case "$_ev" in
        *sink*|*source*|*'server'*) kill -USR1 "$MAIN_PID" 2>/dev/null ;;
    esac
  done ) &

echo '{"version":1,"click_events":true}'
echo '['
echo '[]'
read PREV_TOTAL PREV_IDLE < <(read_cpu)   # prime cpu counters

while true; do
    blocks=()
    mod_pulseaudio
    mod_network
    mod_powerprofile
    mod_cpu
    mod_memory
    mod_temperature
    mod_battery
    mod_clock
    mod_networksettings
    mod_power
    IFS=,; printf ',[%s]\n' "${blocks[*]}"; unset IFS
    # Interruptible sleep: SIGUSR1 kills it for an immediate redraw
    sleep 2 &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null
done
