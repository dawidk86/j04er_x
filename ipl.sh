#!/bin/bash
# IP Location Checker – Fixed & Optimized
# Works on Kali / Ubuntu / Debian / RHEL with curl + jq
# Usage: ./ipcheck.sh <IP> [output_file] OR ./ipcheck.sh -i <list_file>

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo -e "${RED}Error:${NC} Missing dependencies. Please install them:"
    echo "  sudo apt install curl jq  # Debian/Ubuntu/Kali"
    echo "  sudo yum install curl jq  # RHEL/CentOS"
    exit 1
fi

get_location() {
    local ip="$1"
    local json
    
    # Check if IP is valid format roughly before asking API
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return
    fi

    json=$(curl -s --max-time 10 "http://ip-api.com/json/$ip?fields=status,message,country,countryCode,regionName,city,isp,lat,lon,timezone" || echo '{"status":"fail"}')

    if [[ $(echo "$json" | jq -r '.status') == "success" ]]; then
        country=$(echo "$json" | jq -r '.country')
        code=$(echo "$json" | jq -r '.countryCode')
        region=$(echo "$json" | jq -r '.regionName')
        city=$(echo "$json" | jq -r '.city // "N/A"')
        isp=$(echo "$json" | jq -r '.isp // "N/A"')
        lat=$(echo "$json" | jq -r '.lat')
        lon=$(echo "$json" | jq -r '.lon')
        tz=$(echo "$json" | jq -r '.timezone')

        printf "${GREEN}[+]${NC} %-15s → %s (%s) | %s, %s | %s | %s\n" \
            "$ip" "$country" "$code" "$region" "$city" "$isp" "$tz"
    else
        msg=$(echo "$json" | jq -r '.message // "Private/Reserved/Fail"')
        printf "${RED}[-]${NC} %-15s → Failed: %s\n" "$ip" "$msg"
    fi
}

# Extract valid public IPs, ignoring local/private ranges
extract_ips() {
    local line="$1"
    grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<< "$line" | \
    grep -vE '^($|0\.|10\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|255\.255\.255\.255)' | \
    sort -u || true
}

# Process a file line by line
process_file() {
    local file="$1"
    local out="${file%.*}_ipl.txt"

    echo -e "${YELLOW}Processing file: $file${NC}"
    echo -e "${YELLOW}Saving to: $out${NC}"

    # Clear output file
    > "$out"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        
        # Write original line to file for context
        echo "Original: $line" >> "$out"

        mapfile -t ips < <(extract_ips "$line")
        
        if [[ ${#ips[@]} -eq 0 ]]; then
            echo "No Public IPs found." >> "$out"
        fi

        for ip in "${ips[@]}"; do
            # Display to screen
            get_location "$ip" | tee -a "$out"
            # Crucial: Sleep to avoid API Ban (45 req/min limit = ~1.5s delay)
            sleep 1.5 
        done
        echo "----------------------------------------" >> "$out"
    done < "$file"

    echo -e "${GREEN}Done! Check results in: $out${NC}"
}

# Main Logic
if [[ $# -eq 0 ]]; then
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 8.8.8.8             → check one IP"
    echo "  $0 8.8.8.8 result.txt  → check one IP + save"
    echo "  $0 -i list.txt         → check all IPs in file"
    exit 1
fi

if [[ "$1" == "-i" ]]; then
    # Fixed syntax error here
    if [[ ! -f "$2" ]]; then
        echo -e "${RED}File not found: $2${NC}"
        exit 1
    fi
    process_file "$2"
else
    ip="$1"
    output="${2:-}"
    
    if [[ -n "$output" ]]; then
        # Capture output, strip colors for file, keep colors for screen
        result=$(get_location "$ip")
        echo -e "$result"
        echo -e "$result" | sed 's/\x1b\[[0-9;]*m//g' > "$output"
        echo -e "${YELLOW}Saved to $output${NC}"
    else
        get_location "$ip"
    fi
fi
