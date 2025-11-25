#!/bin/bash

# Kali Linux IP Location Checker
# Usage:
#   ./ip_location_checker.sh -i file.txt     → Process all IPs in file, save to file_ipl.txt
#   ./ip_location_checker.sh 8.8.8.8          → Scan single IP and print to terminal
#   ./ip_location_checker.sh 8.8.8.8 output.txt → Scan single IP and save to file

# Dependencies: curl, jq (install: sudo apt install curl jq -y)

INPUT_FILE=""
SINGLE_IP=""
OUTPUT_FILE=""

# === Function: Get location via ip-api.com ===
get_location() {
    local ip="$1"
    local data=$(curl -s --connect-timeout 10 "http://ip-api.com/json/$ip?fields=status,message,country,city,isp,lat,lon,timezone,regionName")
    if [[ $(echo "$data" | jq -r '.status' 2>/dev/null || echo "fail") == "success" ]]; then
        local country=$(echo "$data" | jq -r '.country')
        local city=$(echo "$data" | jq -r '.city')
        local isp=$(echo "$data" | jq -r '.isp')
        local lat=$(echo "$data" | jq -r '.lat')
        local lon=$(echo "$data" | jq -r '.lon')
        local region=$(echo "$data" | jq -r '.regionName')
        local tz=$(echo "$data" | jq -r '.timezone')
        echo "[IP: $ip | Country: $country | Region: $region | City: $city | ISP: $isp | Lat: $lat | Lon: $lon | TZ: $tz]"
    else
        local msg=$(echo "$data" | jq -r '.message' 2>/dev/null || echo "Unknown error")
        [[ "$msg" == "null" || -z "$msg" ]] && msg="Invalid/Private IP"
        echo "[IP: $ip | Location: Failed - $msg]"
    fi
}

# === Function: Extract IPs from a line (IPv4 only) - PRIVATE IP FILTERING DISABLED ===
extract_ips() {
    local line="$1"
    # Extract all IPv4 addresses (including private ones)
    echo "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort -u
}

# === Function: Process file ===
process_file() {
    local input="$1"
    local output="$2"

    > "$output"  # Clear output

    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line" >> "$output"
        local ips=$(extract_ips "$line")
        if [[ -n "$ips" ]]; then
            while IFS= read -r ip; do
                local loc=$(get_location "$ip")
                echo "  $loc" >> "$output"
            done <<< "$ips"
        fi
        echo "" >> "$output"
    done < "$input"

    echo "Processing complete. Output saved to: $output"
}

# === Function: Process single IP ===
process_single_ip() {
    local ip="$1"
    local save_file="$2"

    if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Error: '$ip' is not a valid IPv4 address."
        exit 1
    fi

    echo "Scanning IP: $ip"
    local result=$(get_location "$ip")

    if [[ -n "$save_file" ]]; then
        echo "$ip" > "$save_file"
        echo "$result" >> "$save_file"
        echo "" >> "$save_file"
        echo "Result saved to: $save_file"
    else
        echo "$result"
    fi
}

# === Main Argument Parser ===
if [[ $# -eq 0 ]]; then
    echo "Usage:"
    echo "  $0 -i input.txt                    → Scan all IPs in file"
    echo "  $0 8.8.8.8                         → Scan single IP (print to terminal)"
    echo "  $0 8.8.8.8 output.txt              → Scan single IP and save to file"
    exit 1
fi

# Check if first argument is -i (file mode)
if [[ "$1" == "-i" ]]; then
    if [[ -z "$2" || ! -f "$2" ]]; then
        echo "Error: Input file not provided or does not exist."
        echo "Usage: $0 -i file.txt"
        exit 1
    fi
    INPUT_FILE="$2"
    BASE=$(basename "$INPUT_FILE" .txt)
    DIR=$(dirname "$INPUT_FILE")
    OUTPUT_FILE="${DIR}/${BASE}_ipl.txt"
    process_file "$INPUT_FILE" "$OUTPUT_FILE"

# Otherwise, treat as single IP mode
else
    SINGLE_IP="$1"
    OUTPUT_FILE="$2"  # Optional second arg = save file
    process_single_ip "$SINGLE_IP" "$OUTPUT_FILE"
fi