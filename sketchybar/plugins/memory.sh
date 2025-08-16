#!/bin/bash
# SketchyBar Memory Pressure (proxy) for macOS
# Save as ~/.config/sketchybar/plugins/memory.sh
# chmod +x ~/.config/sketchybar/plugins/memory.sh

source $CONFIG_DIR/colors.sh

vm_stat_out="$(vm_stat)"
page_size="$(/usr/sbin/sysctl -n hw.pagesize)"

get_pages () { 
  # Grep a "Pages X" line robustly, extract the last numeric field, strip trailing '.'
  echo "$vm_stat_out" | awk -v k="$1" '$0 ~ k {gsub("\\.","",$NF); print $NF; exit}'
}

pages_active="$(get_pages '^Pages active')"
pages_wired="$(get_pages '^Pages wired down|^Pages wired')"   # name varies by macOS
pages_inactive="$(get_pages '^Pages inactive')"
pages_speculative="$(get_pages '^Pages speculative')"
pages_free="$(get_pages '^Pages free')"
pages_purgeable="$(get_pages '^Pages purgeable')"
pages_compressed="$(get_pages '^Pages occupied by compressor')"

# Convert pages -> MiB
to_mib () { echo $(( ($1 * page_size) / 1024 / 1024 )); }

active_mib="$(to_mib ${pages_active:-0})"
wired_mib="$(to_mib ${pages_wired:-0})"
inactive_mib="$(to_mib ${pages_inactive:-0})"
speculative_mib="$(to_mib ${pages_speculative:-0})"
free_mib="$(to_mib ${pages_free:-0})"
purgeable_mib="$(to_mib ${pages_purgeable:-0})"
compressed_mib="$(to_mib ${pages_compressed:-0})"

# Total RAM (approx) = sum of everything we see (good enough for % calc)
total_mib=$(( active_mib + wired_mib + inactive_mib + speculative_mib + free_mib + compressed_mib ))

# Effective "reclaimable" cache = inactive + speculative + purgeable
reclaimable_mib=$(( inactive_mib + speculative_mib + purgeable_mib ))

# Effective used = wired + active + compressed - purgeable (since purgeable can be reclaimed)
used_effective_mib=$(( wired_mib + active_mib + compressed_mib - purgeable_mib ))
if [ $used_effective_mib -lt 0 ]; then used_effective_mib=0; fi

# Swap usage (in MB)
swap_used_mb="$(/usr/sbin/sysctl -n vm.swapusage 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i ~ /^used=/){gsub("M","",$i); split($i,a,"="); print int(a[2]); exit}}}')"
swap_used_mb="${swap_used_mb:-0}"

# Base pressure from effective used
# (integer math; clamp to [0,100])
if [ $total_mib -gt 0 ]; then
  base_pressure=$(( 100 * used_effective_mib / total_mib ))
else
  base_pressure=0
fi

# Penalties for compression & swap (signs of strain)
penalty=0
# +8 if compressed > 1024 MiB, +16 if > 2048 MiB
if [ $compressed_mib -gt 2048 ]; then penalty=$((penalty+16))
elif [ $compressed_mib -gt 1024 ]; then penalty=$((penalty+8)); fi
# +8 if swap > 512 MB, +20 if > 2048 MB
if [ $swap_used_mb -gt 2048 ]; then penalty=$((penalty+20))
elif [ $swap_used_mb -gt 512 ]; then penalty=$((penalty+8)); fi

pressure=$(( base_pressure + penalty ))
if [ $pressure -gt 100 ]; then pressure=100; fi
if [ $pressure -lt 0 ]; then pressure=0; fi

# Pick a color by pressure
# Green <= 60, Yellow <= 75, Orange <= 90, Red > 90
if   [ $pressure -le 60 ]; then color=$GREEN  # green-500
elif [ $pressure -le 75 ]; then color=$YELLOW # yellow-500
elif [ $pressure -le 90 ]; then color=$ORANGE # orange-500
else                            color=$RED     # red-500
fi

# Nice compact label: PRESSURE%  (Swap, Comp)
# Show swap in GB if large, else MB
fmt_bytes () {
  local mb="$1"
  if [ "$mb" -ge 1024 ]; then
    printf "%.1fG" "$(echo "scale=1; $mb/1024" | bc -l)"
  else
    printf "%dM" "$mb"
  fi
}
swap_str="$(fmt_bytes "$swap_used_mb")"
comp_str="$(printf "%.1fG" "$(echo "scale=1; $compressed_mib/1024" | bc -l)")"

# Icon idea: memory chip (nf-md-memory)

label="${pressure}% (S:${swap_str} C:${comp_str})"

sketchybar --set "$NAME" label="$label" label.color=$color
