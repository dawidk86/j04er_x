#!/bin/bash
# Kali Linux IP Location Checker - FIXED & ROBUST VERSION
# Usage:
#   ./ip_location_checker.sh -i file.txt
#   ./ip_location_checker.sh 8.8.8.8
#   ./ip_location_checker.sh 8.8.8.8 output.txt
# Dependencies: curl, jq

set -uo pipefail

# === Function: Get location via ip-api.com (free, 45 req/min limit) ===
get_location() {
    local ip="$1"
    local data
    data=$(curl -s --connect-timeout 10 --max-time 20 \
        "http://ip-api.com/json/$ip?fields=status,message,country,countryCode,city,isp,lat,lon,timezone,regionName,query" \
        2>/dev/null || echo '{"status":"fail","message":"curl failed"}')

    if [[ $(echo "$data" | jq -r '.status // "fail"') == "success" ]]; then
        local country=$(echo "$data" | jq -r '.country')
        local countryCode=$(echo "$data" | jq -r '.countryCode')
        local region=$(echo "$data" | jq -r '.regionName')
        local city=$(echo "$data" | jq -r '.city')
        local isp=$(echo "$data" | jq -r '.isp')
        local lat=$(echo "$data | jq -r '.lat')
        local lon=$(echo "$data" | jq -r '.lon')
        local tz=$(echo "$data" | jq -r '.timezone')
        printf '[+] %s | %s (%s) | %s, %s | ISP: %s | Coord: %s,%s | TZ: %s\n' \
            "$ip" "$country" "$countryCode" "$region" "$city" "$isp" "$lat" "$lon" "$tz"
    else
        local msg=$(echo "$data" | jq -r '.message // "Unknown error"')
        [[ "$msg" == "null" ]] && msg="Private/Reserved IP"
        printf '[-] %s | Failed - %s\n' "$ip" "$msg"
    fi
}

# === Extract IPv4 addresses from text (robust regex) ===
extract_ips() {
    local line="$1"
    grep -oE '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b' <<< "$line" | sort -u
}

# === Process entire file safely (no stdin conflict) ===
process_file() {
    local input="$1"
    local output="$2"

    > "$output"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "${line// }" ]] && { echo ""; continue; }

        echo "$line" >> "$output"

        # Use mapfile to safely read IPs without conflicting with outer loop
        mapfile -t ips < <(extract_ips "$line")

        if (( ${#ips[@]} )); then
            for ip in "${ips[@]}"; do
                result=$(get_location "$ip")
                printf "   %s\n" "$result" >> "$output"
            done
        fi
        echo "" >> "$output"
    done < "$input"

    echo "Processing complete → $output"
}

# === Process single IP ===
process_single_ip() {
    local ip="$1"
    local save_file="${2:-}"

    # Validate IPv4
    if ! [[ $ip =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
        echo "Error: '$ip' is not a valid IPv4 address."
        exit 1
    fi

    echo "Scanning IP: $ip"
    result=$(get_location "$ip")

    if [[ -n "$save_file" ]]; then
        {
            echo "IP: $ip"
            echo "$result"
            echo ""
        } > "$save_file"
        echo "Result saved to: $save_file"
    else
        echo "$result"
    fi
}

# === Main ===
if [[ $# -eq 0 ]]; then
    cat <<EOF
Usage:
  $0 -i input.txt           → Process file, save to input_ipl.txt
  $0 8.8.8.8                → Scan single IP (print)
  $0 8.8.8.8 result.txt     → Scan single IP + save
EOF
    exit 1
fi

if [[ "$1" == "-i" ]]; then
    [[ -z "${2:-}" || ! -f "$2" ]] && { echo "Error: File not found: $2"; exit 1; }
    input_file="$2"
    base=$(basename "$input_file" .txt)
    dir=$(dirname "$input_file")
    output_file="${dir}/${base}_ipl.txt"
    process_file "$input_file" "$output_file"
else
    process_single_ip "$1" "${2:-}"
fi
