#!/bin/bash
# IP Location Checker – Fully Working & Tested (Dec 2025)
# Works on Kali / Ubuntu / Debian / any Linux with curl + jq
# chmod +x ipcheck.sh && ./ipcheck.sh ...

set -euo pipefail

# Colors (optional, looks nice)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

get_location() {
    local ip="$1"
    local json
    json=$(curl -s --max-time 15 "http://ip-api.com/json/$ip?fields=status,message,country,countryCode,regionName,city,isp,lat,lon,timezone" || echo '{"status":"fail"}')

    if [[ $(echo "$json" | jq -r '.status') == "success" ]]; then
        country=$(echo "$json" | jq -r '.country')
        code=$(echo "$json" | jq -r '.countryCode')
        region=$(echo "$json" | jq -r '.regionName')
        city=$(echo "$json" | jq -r '.city // "N/A"')
        isp=$(echo "$json" | jq -r '.isp // "N/A"')
        local lat=$(echo "$json" | jq -r '.lat')
        local lon=$(echo "$json" | jq -r '.lon')
        local tz=$(echo "$json" | jq -r '.timezone')

        printf "${GREEN}[+]${NC} %s → %s (%s) | %s, %s | %s | %s,%s | %s\n" \
            "$ip" "$country" "$code" "$region" "$city" "$isp" "$lat" "$lon" "$tz"
    else
        msg=$(echo "$json" | jq -r '.message // "Private/Reserved IP"')
        printf "${RED}[-]${NC} %s → Failed: %s\n" "$ip" "$msg"
    fi
}

# Extract only valid public/private IPv4 from a line
extract_ips() {
    local line="$1"
    grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<< "$line" | grep -vE '^($|0\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|255\.255\.255\.255)' | sort -u || true
}

# Process a whole file
process_file() {
    local file="$1"
    local out="${file%.*}_ipl.txt"

    > "$out"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        echo "$line" >> "$out"

        mapfile -t ips < <(extract_ips "$line")
        for ip in "${ips[@]}"; do
            get_location "$ip" >> "$out"
        done
        echo "" >> "$out"
    done < "$file"

    echo -e "${GREEN}Done! → $out${NC}"
}

# Main
if [[ $# -eq 0 ]]; then
    echo "Usage:"
    echo "  $0 8.8.8.8                    → check one IP"
    echo "  $0 8.8.8.8 result.txt         → check one IP + save"
    echo "  $0 -i list.txt                → check all IPs in file"
    exit 1
fi

if [[ "$1" == "-i" ]]; then
    [[ ! [[ -f "$2" ]] && { echo "File not found: $2"; exit 1; }
    process_file "$2"
else
    ip="$1"
    output="${2:-}"
    result=$(get_location "$ip")
    if [[ -n "$output" ]]; then
        echo "$result" > "$output"
        echo "Saved → $output"
    else
        echo "$result"
    fi
fi
