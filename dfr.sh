#!/bin/bash

# File: file_compare.sh
# Usage: ./file_compare.sh -a file1.txt -b file2.txt
# Result: Saves differences to dfr.txt (overwritten each time)

# Default values
FILE_A=""
FILE_B=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a)
            FILE_A="$2"
            shift 2
            ;;
        -b)
            FILE_B="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 -a <file1> -b <file2>"
            exit 1
            ;;
    esac
done

# Check if both files are provided
if [[ -z "$FILE_A" || -z "$FILE_B" ]]; then
    echo "Error: Both -a and -b options are required."
    echo "Usage: $0 -a <file1> -b <file2>"
    exit 1
fi

# Check if files exist
if [[ ! -f "$FILE_A" ]]; then
    echo "Error: File not found: $FILE_A"
    exit 1
fi

if [[ ! -f "$FILE_B" ]]; then
    echo "Error: File not found: $FILE_B"
    exit 1
fi

# Perform comparison using diff with unified format and color (if terminal supports)
echo "Comparing:"
echo "   $FILE_A"
echo "   $FILE_B"
echo "Differences saved to: dfr.txt"
echo "---------------------------------------------------"

# Use diff with context and clear markers
diff -u --color=always "$FILE_A" "$FILE_B" > dfr.txt

# Check if there were differences
if [[ $? -eq 0 ]]; then
    echo "No differences found. dfr.txt is empty."
    > dfr.txt  # Create empty file for consistency
else
    echo "Differences found! See dfr.txt for details."
    echo "Total changes: $(grep -c "^[+-]" dfr.txt || echo 0)"
fi

# Optional: show preview (first 20 lines)
echo ""
echo "Preview of differences:"
echo "======================="
if [[ -s dfr.txt ]]; then
    head -n 20 dfr.txt
    if [[ $(wc -l < dfr.txt) -gt 20 ]]; then
        echo "... (see dfr.txt for full output)"
    fi
else
    echo "No differences."
fi
