sudo tee /usr/local/bin/ipp > /dev/null << 'EOF'
#!/bin/bash
# ipp — Auto-self-installing version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
TARGET="/usr/local/bin/ipp"

# === AUTO INSTALL ON FIRST RUN ===
# Only run install logic if NOT running from the target location
if [[ "$1" != "--installed" ]] && [[ "$SCRIPT_DIR/$SCRIPT_NAME" != "$TARGET" ]]; then
    echo "Installing ipp command system-wide..."
    cp "$SCRIPT_DIR/$SCRIPT_NAME" "$TARGET"
    chmod +x "$TARGET"
    echo "Installation complete! Now just run: ipp -i your_file.txt"
    exec "$TARGET" --installed "$@"
fi

# === FIX: ONLY SHIFT IF FLAG IS PRESENT ===
if [[ "$1" == "--installed" ]]; then
    shift
fi

# === NORMAL OPERATION ===
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

INPUT_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input) INPUT_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ipp -i <file_or_folder>"
            echo "Keeps only IP:PORT lines → saves as <file>_Y.txt"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

[[ -z "$INPUT_PATH" ]] && { echo -e "${RED}Error: -i <file_or_folder> required${NC}"; exit 1; }
[[ ! -e "$INPUT_PATH" ]] && { echo -e "${RED}Error: Path not found: $INPUT_PATH${NC}"; exit 1; }

process_file() {
    local FILE="$1"
    [[ ! -f "$FILE" ]] && return

    local OUTPUT="${FILE%.*}_Y.txt"
    
    grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+(\s|$)' "$FILE" > "$OUTPUT"

    local KEPT=$(wc -l < "$OUTPUT" 2>/dev/null || echo 0)
    local TOTAL=$(wc -l < "$FILE" 2>/dev/null || echo 0)
    local REMOVED=$((TOTAL - KEPT))

    echo -e "${BLUE}Processing: $FILE${NC}"
    echo -e "Lines: $TOTAL total → ${GREEN}$KEPT kept${NC} ($REMOVED removed)"
    echo -e "Saved: $OUTPUT\n"
}

if [[ -d "$INPUT_PATH" ]]; then
    echo -e "${GREEN}Directory detected. Scanning files in: $INPUT_PATH${NC}\n"
    for entry in "$INPUT_PATH"/*; do
        process_file "$entry"
    done
else
    process_file "$INPUT_PATH"
fi

echo -e "${GREEN}All tasks finished!${NC}"
EOF

sudo chmod +x /usr/local/bin/ipp
echo "ipp fixed! Try running: ipp -i folder"