#!/bin/bash

CLI="$HOME/projects/boenan/ipinfo/ipinfo-cli"
IPINFO_TOKEN="$(/usr/bin/security find-generic-password -a "$USER" -s ipinfo_token -w 2>/dev/null)"
OUTPUT=$($CLI -token $IPINFO_TOKEN -json true)

IP=$(jq -r '.ip //  ""' <<<"$OUTPUT")
CITY=$(jq -r '.city // ""' <<<"$OUTPUT")
COUNTRY=$(jq -r '.country_name // ""' <<<"$OUTPUT")
FLAG=$(jq -r '.flag // ""' <<<"$OUTPUT")

sketchybar --set ipitem_text icon="$FLAG $CITY $COUNTRY" label="($IP)"
# sketchybar --set ipitem_ip label="($IP)"
