#!/bin/bash

# ap - add prefix or suffix to every line of a file
# Installed system-wide as: ap

set -euo pipefail

show_help() {
    cat <<EOF
Usage: ap -i <input_file> (-a <prefix> | -p <suffix>)

  -i <file>   Input text file (required)
  -a <text>   Add <text> at the beginning of each line
  -p <text>   Add <text> at the end of each line

Examples:
  ap -i hosts.txt -a "https://"
  ap -i ports.txt -p ":8080"

Output: <original>_ap.<ext>  (or <original>_ap if no extension)
EOF
    exit 1
}

# ----- Parse arguments -----
input_file=""
prefix=""
suffix=""

while (( $# )); do
    case "$1" in
        -i) input_file="$2"; shift 2 ;;
        -a) prefix="$2";   shift 2 ;;
        -p) suffix="$2";   shift 2 ;;
        -h|--help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

# ----- Validation -----
[[ -z "$input_file" ]] && { echo "Error: -i <file> is required"; show_help; }
[[ ! -f "$input_file" ]] && { echo "Error: File not found: $input_file"; exit 1; }

if [[ -z "$prefix" && -z "$suffix" ]]; then
    echo "Error: Must use either -a or -p"
    show_help
fi
if [[ -n "$prefix" && -n "$suffix" ]]; then
    echo "Error: Cannot use both -a and -p"
    show_help
fi

# ----- Build output filename -----
base=$(basename "$input_file")
dir=$(dirname "$input_file")
ext="${base##*.}"
name="${base%.*}"

if [[ "$base" == "$ext" ]]; then
    out="$dir/${name}_ap"
else
    out="$dir/${name}_ap.$ext"
fi

# ----- Escape text for sed -----
escape() {
    printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'
}

# ----- Apply transformation -----
if [[ -n "$prefix" ]]; then
    esc_prefix=$(escape "$prefix")
    sed "s/^/$esc_prefix/" "$input_file" > "$out"
else
    esc_suffix=$(escape "$suffix")
    sed "s/$/$esc_suffix/" "$input_file" > "$out"
fi

echo "Created: $out"