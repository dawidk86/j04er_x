#!/bin/bash

# ==============================================================================
#  ADVANCED BRUTE FORCE SUITE v5.1 (Added Length Config)
# ==============================================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Cleanup Function ---
cleanup() {
    if [ -f "/tmp/pymulticrack.py" ]; then
        rm -f "/tmp/pymulticrack.py"
    fi
}
trap cleanup EXIT

# --- Logo ---
print_logo() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
     _____                 _                
    / ____|               | |               
   | |      _ __ __ _  ___| | _____ _ __    
   | |     | '__/ _` |/ __| |/ / _ \ '__|   
   | |____ | | | (_| | (__|   <  __/ |      
    \_____||_|  \__,_|\___|_|\_\___|_|      
                                            
    [ v5.1 :: MASK & WORDLIST MANAGER ]
EOF
    echo -e "${NC}"
}

# --- Auto Detect Target Type ---
auto_detect_target() {
    local target_file="$1"
    
    # Check Archive
    if file "$target_file" | grep -q "Zip archive data"; then echo "ZIP"; return; fi
    if file "$target_file" | grep -q "RAR archive data"; then echo "RAR"; return; fi
    
    # Check Hash
    local first_line
    first_line=$(head -n 1 "$target_file" | tr -d '\n\r ' | awk -F ':' '{print $1}')
    local len=${#first_line}

    if [[ "$first_line" == '$'* ]]; then echo "SPECIAL_HASH"; return; fi
    if [[ $len -eq 32 && $first_line =~ ^[0-9a-fA-F]+$ ]]; then echo "MD5"; return; fi
    if [[ $len -eq 40 && $first_line =~ ^[0-9a-fA-F]+$ ]]; then echo "SHA1"; return; fi
    if [[ $len -eq 64 && $first_line =~ ^[0-9a-fA-F]+$ ]]; then echo "SHA256"; return; fi

    echo "UNKNOWN"
}

# --- Main Logic Start ---
print_logo

# 1. Select Tool
echo -e "${YELLOW}Select Cracking Tool:${NC}"
echo -e "1) ${GREEN}Hashcat${NC} (GPU - Best for Masks)"
echo -e "2) ${BLUE}John the Ripper${NC} (CPU - Reliable)"
echo -e "3) ${RED}Python Script${NC} (Native - Custom Logic)"
read -p "Choice [1-3]: " tool_choice

# 2. Get Filename
echo
read -p "Enter filename/path to crack: " target_file
if [ ! -f "$target_file" ]; then
    echo -e "${RED}Error: File not found!${NC}"
    exit 1
fi

# 3. Detect Type (Preprocessing)
detected_type=$(auto_detect_target "$target_file")
echo -e "${CYAN}[*] File Type Detected: $detected_type${NC}"

# Handle extraction for ZIP/RAR/Hash before asking for attack mode
hash_file="hash_ready.txt"
# Default copies, overridden below
cp "$target_file" "$hash_file" 2>/dev/null 

# Hashcat/John specific extraction logic
if [ "$tool_choice" == "1" ] || [ "$tool_choice" == "2" ]; then
    if [ "$detected_type" == "ZIP" ]; then
        echo "[*] Extracting ZIP hash..."
        zip2john "$target_file" > "$hash_file" 2>/dev/null
        # Clean hash for Hashcat
        if [ "$tool_choice" == "1" ]; then
            sed -i 's/^.*$zip/$zip/' "$hash_file"
        fi
    elif [ "$detected_type" == "RAR" ]; then
        echo "[*] Extracting RAR hash..."
        rar2john "$target_file" > "$hash_file" 2>/dev/null
    fi
fi

# 4. ASK ATTACK MODE
echo
echo -e "${YELLOW}Select Attack Mode:${NC}"
echo "1) Wordlist Attack (Dictionary)"
echo "2) Mask Attack (Brute Force - Charset Selection)"
read -p "Choice [1-2]: " attack_mode

# --- CONFIGURING ATTACK VARIABLES ---

ATTACK_TYPE=""
WORDLIST_PATH=""
MASK_CHARSET="" 
PY_CHARSET_CODE=""
MIN_LEN=1
MAX_LEN=6

if [ "$attack_mode" == "1" ]; then
    # --- WORDLIST SETUP ---
    ATTACK_TYPE="wordlist"
    read -p "Enter path to wordlist (Press Enter for rockyou.txt): " wl_input
    if [ -z "$wl_input" ]; then
        WORDLIST_PATH="/usr/share/wordlists/rockyou.txt"
    else
        WORDLIST_PATH="$wl_input"
    fi
    
    if [ ! -f "$WORDLIST_PATH" ]; then
        echo -e "${RED}Wordlist not found at $WORDLIST_PATH${NC}"
        exit 1
    fi

elif [ "$attack_mode" == "2" ]; then
    # --- MASK / BRUTE FORCE SETUP ---
    ATTACK_TYPE="mask"
    echo -e "${BLUE}--- Configure Mask ---${NC}"
    
    # 1. Select Charsets
    read -p "Include Lowercase (a-z)? [y/n]: " use_lower
    read -p "Include Uppercase (A-Z)? [y/n]: " use_upper
    read -p "Include Numbers   (0-9)? [y/n]: " use_num
    read -p "Include Specials  (!@#)? [y/n]: " use_spec
    
    # 2. Select Lengths (NEW FEATURE)
    echo -e "${BLUE}--- Configure Length ---${NC}"
    read -p "Minimum Password Length [Default: 1]: " in_min
    read -p "Maximum Password Length [Default: 8]: " in_max

    # Set defaults if empty
    MIN_LEN=${in_min:-1}
    MAX_LEN=${in_max:-8}

    # Build Hashcat/John Charsets
    hc_mask=""
    john_mask_param=""
    py_chars=""

    if [[ "$use_lower" =~ ^[Yy]$ ]]; then 
        hc_mask="${hc_mask}?l"
        john_mask_param="${john_mask_param}l"
        py_chars="${py_chars}string.ascii_lowercase + "
    fi
    if [[ "$use_upper" =~ ^[Yy]$ ]]; then 
        hc_mask="${hc_mask}?u"
        john_mask_param="${john_mask_param}u"
        py_chars="${py_chars}string.ascii_uppercase + "
    fi
    if [[ "$use_num" =~ ^[Yy]$ ]]; then 
        hc_mask="${hc_mask}?d"
        john_mask_param="${john_mask_param}d"
        py_chars="${py_chars}string.digits + "
    fi
    if [[ "$use_spec" =~ ^[Yy]$ ]]; then 
        hc_mask="${hc_mask}?s"
        john_mask_param="${john_mask_param}s"
        py_chars="${py_chars}string.punctuation + "
    fi

    # Fallback
    if [ -z "$hc_mask" ]; then
        echo -e "${RED}No characters selected. Defaulting to full ASCII.${NC}"
        hc_mask="?a"
        john_mask_param="print"
        py_chars="string.printable"
    else
        py_chars=${py_chars% + }
    fi

    MASK_CHARSET="$hc_mask"
    PY_CHARSET_CODE="$py_chars"

else
    echo "Invalid Attack Mode."
    exit 1
fi

echo -e "${GREEN}Configuration Complete. Starting Tool...${NC}"
sleep 1

# ==============================================================================
# TOOL EXECUTION
# ==============================================================================

# -----------------------------------
# TOOL 1: HASHCAT
# -----------------------------------
if [ "$tool_choice" == "1" ]; then
    
    # Detect Mode ID
    hc_mode=""
    case "$detected_type" in
        "MD5") hc_mode="0" ;;
        "SHA1") hc_mode="100" ;;
        "SHA256") hc_mode="1400" ;;
        "ZIP") hc_mode="13600" ;;
        "RAR") hc_mode="13000" ;;
        *) read -p "Unknown type. Enter Hashcat Mode ID (e.g., 0): " hc_mode ;;
    esac

    if [ "$ATTACK_TYPE" == "wordlist" ]; then
        echo -e "${YELLOW}Running: hashcat -m $hc_mode -a 0 $hash_file $WORDLIST_PATH${NC}"
        hashcat -m "$hc_mode" -a 0 "$hash_file" "$WORDLIST_PATH" --force
    else
        # Mask Mode with Dynamic Length
        echo -e "${YELLOW}Running Hashcat Mask Attack...${NC}"
        echo "Custom Charset: $MASK_CHARSET"
        echo "Length: $MIN_LEN to $MAX_LEN"
        
        # Build dynamic mask string (e.g., ?1?1?1...) based on MAX_LEN
        full_mask=""
        for ((i=1; i<=MAX_LEN; i++)); do
           full_mask="${full_mask}?1"
        done

        # -1 defines charset, ?1... defines the mask structure
        # --increment-min and --increment-max limit the attack range
        hashcat -m "$hc_mode" -a 3 -1 "$MASK_CHARSET" "$hash_file" "$full_mask" --increment --increment-min="$MIN_LEN" --increment-max="$MAX_LEN" --force
    fi

# -----------------------------------
# TOOL 2: JOHN THE RIPPER
# -----------------------------------
elif [ "$tool_choice" == "2" ]; then
    
    fmt_flag=""
    if [ "$detected_type" == "MD5" ]; then fmt_flag="--format=raw-md5"; fi
    if [ "$detected_type" == "SHA1" ]; then fmt_flag="--format=raw-sha1"; fi
    
    if [ "$ATTACK_TYPE" == "wordlist" ]; then
        echo -e "${YELLOW}Running John Wordlist...${NC}"
        john $fmt_flag --wordlist="$WORDLIST_PATH" "$hash_file"
    else
        echo -e "${YELLOW}Running John Mask Attack...${NC}"
        
        # Build dynamic mask string based on MAX_LEN
        john_mask_string=""
        for ((i=1; i<=MAX_LEN; i++)); do
           john_mask_string="${john_mask_string}?1"
        done

        # Note: John's standard mask mode is less flexible with exact ranges than Hashcat
        # We generally target the max length here.
        echo "Mask: $MASK_CHARSET (Max Len: $MAX_LEN)"
        john $fmt_flag --mask="$john_mask_string" -1="$MASK_CHARSET" "$hash_file"
    fi
    
    john --show "$hash_file"

# -----------------------------------
# TOOL 3: PYTHON (PyMultiCrack)
# -----------------------------------
elif [ "$tool_choice" == "3" ]; then
    
    echo -e "${YELLOW}Generating Python Script...${NC}"
    
    cat << EOF > /tmp/pymulticrack.py
import hashlib
import sys
import itertools
import string
import time

target_file = "$target_file"
attack_mode = "$ATTACK_TYPE"
target_hash = ""

# Read Hash
try:
    with open(target_file, 'r') as f:
        target_hash = f.readline().strip().split(':')[0]
except:
    print("Error reading file")
    sys.exit()

print(f"Target Hash: {target_hash}")

def check_pass(p):
    if hashlib.md5(p.encode()).hexdigest() == target_hash:
        print(f"\n{'-'*30}\nCRACKED: {p}\n{'-'*30}")
        return True
    return False

if attack_mode == "wordlist":
    wlist = "$WORDLIST_PATH"
    print(f"Using Wordlist: {wlist}")
    try:
        with open(wlist, 'r', encoding='latin-1') as f:
            for line in f:
                pwd = line.strip()
                if check_pass(pwd): sys.exit()
    except FileNotFoundError:
        print("Wordlist file not found.")

elif attack_mode == "mask":
    chars = $PY_CHARSET_CODE
    print(f"Brute Forcing with charset length: {len(chars)}")
    print(f"Length Range: $MIN_LEN to $MAX_LEN")
    
    # DYNAMIC LENGTH LOOP
    # Python range is exclusive at the end, so we do MAX_LEN + 1
    for length in range($MIN_LEN, $MAX_LEN + 1):
        print(f"Trying length {length}...")
        for p_tuple in itertools.product(chars, repeat=length):
            pwd = "".join(p_tuple)
            if check_pass(pwd): sys.exit()

print("Failed to crack.")
EOF

    echo -e "${GREEN}Running Python Script...${NC}"
    python3 /tmp/pymulticrack.py

fi

# Final Cleanup handled by trap
echo
echo "Process finished."
