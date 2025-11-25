#!/bin/bash

# Advanced Brute Force Wrapper v2.0 - Hashcat / John / Python (FIXED & CLEAN)
# Tested on Kali 2025.4

clear
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Advanced Brute Force Tool for Kali Linux             ║"
echo "║     Hashcat • John the Ripper • Pure Python              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo

echo "Select cracking tool:"
echo "1) Hashcat (GPU+CPU - fastest)"
echo "2) John the Ripper (CPU - reliable)"
echo "3) Python (educational / fallback)"
read -p "Enter choice (1/2/3): " tool_choice

# ═══════════════════════════════════════════════════════════
# 1) HASHCAT
# ═══════════════════════════════════════════════════════════
if [ "$tool_choice" == "1" ]; then
    if ! command -v hashcat &> /dev/null; then
        echo "Error: hashcat not installed → sudo apt install hashcat"
        exit 1
    fi

    echo
    echo "Select target type:"
    echo "1) MD5 hash file"
    echo "2) ZIP archive"
    echo "3) RAR archive"
    read -p "Choice (1/2/3): " target_type
    read -p "Enter filename (same folder): " target_file
    [ ! -f "$target_file" ] && echo "File not found!" && exit 1

    hash_file="hash.tmp"
    mode=""

    case "$target_type" in
        1) mode=0; hash_file="$target_file" ;;
        2) 
          zip2john "$target_file" > "$hash_file" 2>/dev/null || { echo "ZIP hash extraction failed"; exit 1; }
          # === THIS IS THE FIX ===
          grep -o '\$zip2\$.*\$/zip2\$' "$hash_file" > "${hash_file}.clean"
          mv "${hash_file}.clean" "$hash_file"
          # === END FIX ===
          [[ $(head -1 "$hash_file") == *'$pkzip$'* ]] && mode=17200 || mode=13600 
          ;;
        3) rar2john "$target_file" > "$hash_file" 2>/dev/null || { echo "RAR hash extraction failed"; exit 1; }
           [[ $(head -1 "$hash_file") == *'$RAR3$'* ]] && mode=12500 || mode=13000 ;;
        *) echo "Invalid type"; exit 1 ;;
    esac

    echo
    echo "Attack mode:"
    echo "1) Wordlist"
    echo "2) Mask (brute-force)"
    echo "3) Hybrid (wordlist + mask)"
    echo "4) Wordlist + Rules"
    read -p "Choice (1-4): " attack_type

    # Wordlist
    read -p "Custom wordlist? (y/n, default rockyou.txt): " cust
    if [[ $cust == "y" ]]; then
        read -p "Path: " wordlist
    else
        wordlist="/usr/share/wordlists/rockyou.txt"
    fi
    [ ! -f "$wordlist" ] && echo "Wordlist not found!" && exit 1

    # Mask builder
    mask=""; custom_charset=""; increment=""
    if [[ "$attack_type" == "2" || "$attack_type" == "3" ]]; then
        read -p "Custom mask? (e.g. ?l?l?l?d?d?d, leave empty to build): " mask
        if [ -z "$mask" ]; then
            cs=""
            [[ $(read -p "Lowercase [y/n]: "; echo $REPLY) == "y" ]] && cs+="?l"
            [[ $(read -p "Uppercase [y/n]: "; echo $REPLY) == "y" ]] && cs+="?u"
            [[ $(read -p "Digits    [y/n]: "; echo $REPLY) == "y" ]] && cs+="?d"
            [[ $(read -p "Special   [y/n]: "; echo $REPLY) == "y" ]] && cs+="?s"
            [ -z "$cs" ] && echo "No charset chosen!" && exit 1
            read -p "Min length: " min_len
            read -p "Max length: " max_len
            mask=$(printf "?1%.0s" $(seq 1 $max_len))
            custom_charset="-1 $cs"
            increment="--increment --increment-min $min_len --increment-max $max_len"
        fi
    fi

    # Rules
    rules_opt=""
    if [ "$attack_type" == "4" ]; then
        read -p "Rules file (leave empty for none): " rules
        [ -n "$rules" ] && [ -f "$rules" ] && rules_opt="-r $rules"
    fi

    # Build attack args
    case "$attack_type" in
        1) attack_mode=0; extra="$wordlist" ;;
        2) attack_mode=3; extra="$mask $custom_charset $increment" ;;
        3) attack_mode=6; extra="$wordlist $mask $custom_charset $increment" ;;
        4) attack_mode=0; extra="$wordlist $rules_opt" ;;
    esac

    # Workload & session
    echo "Workload: 1=Low 2=Medium 3=High 4=Insane (default 3)"
    read -p "Choice: " wl; wl=${wl:-3}
    read -p "Resume session? (y/n): " resume
    session=""; [ "$resume" == "y" ] && session="--session=brute --restore"

    # Final command
    cmd="hashcat -m $mode -a $attack_mode -w $wl --potfile-disable --status --status-timer=60 -o cracked.txt $session $hash_file $extra"
    echo
    echo "Running:"
    echo "$cmd"
    echo
    $cmd

    [ -f cracked.txt ] && echo "CRACKED →" && cat cracked.txt
    [[ "$target_type" != "1" ]] && rm -f "$hash_file"

# ═══════════════════════════════════════════════════════════
# 2) JOHN THE RIPPER (fixed --status-interval bug!)
# ═══════════════════════════════════════════════════════════
elif [ "$tool_choice" == "2" ]; then
    if ! command -v john &> /dev/null; then
        echo "Error: john not installed → sudo apt install john"
        exit 1
    fi

    echo
    echo "Target type:"
    echo "1) MD5 hash file"
    echo "2) ZIP"
    echo "3) RAR"
    read -p "Choice (1-3): " target_type
    read -p "Filename: " target_file
    [ ! -f "$target_file" ] && echo "Not found!" && exit 1

    hash_file="hash.tmp"
    format=""

    case "$target_type" in
        1) format="raw-md5"; hash_file="$target_file" ;;
        2) zip2john "$target_file" > "$hash_file" 2>/dev/null || { echo "ZIP failed"; exit 1; }; format="zip" ;;
        3) rar2john "$target_file" > "$hash_file" 2>/dev/null || { echo "RAR failed"; exit 1; }; format="rar" ;;
    esac

    echo
    echo "Attack:"
    echo "1) Wordlist"
    echo "2) Mask"
    echo "3) Hybrid"
    echo "4) Incremental"
    read -p "Choice (1-4): " attack_type

    # Wordlist
    read -p "Custom wordlist? (y/n): " cust
    if [[ $cust == "y" ]]; then read -p "Path: " wordlist; else wordlist="/usr/share/wordlists/rockyou.txt"; fi
    [ ! -f "$wordlist" ] && echo "Wordlist missing!" && exit 1

    extra_args=""
    mask_opt=""

    if [[ "$attack_type" == "2" || "$attack_type" == "3" ]]; then
        read -p "Mask (empty to build): " mask
        if [ -z "$mask" ]; then
            cs=""
            [[ $(read -p "Lower [y/n]: "; echo $REPLY) == "y" ]] && cs+="a-z"
            [[ $(read -p "Upper [y/n]: "; echo $REPLY) == "y" ]] && cs+="A-Z"
            [[ $(read -p "Digits [y/n]: "; echo $REPLY) == "y" ]] && cs+="0-9"
            [[ $(read -p "Special [y/n]: "; echo $REPLY) == "y" ]] && cs+="!@#$%^&*"
            read -p "Min length: " min_len
            read -p "Max length: " max_len
            mask=$(printf "?a%.0s" $(seq 1 $max_len))
            extra_args="--min-length=$min_len --max-length=$max_len"
        fi
        mask_opt="--mask=$mask"
    fi

    if [ "$attack_type" == "4" ]; then
        read -p "Incremental mode (Alpha, Digits, Alnum, All): " inc_mode
        read -p "Min length: " min_len
        read -p "Max length: " max_len
        extra_args="--incremental=$inc_mode --min-length=$min_len --max-length=$max_len"
    fi

    # Rules
    rules_opt=""
    if [[ "$attack_type" == "1" || "$attack_type" == "3" ]]; then
        read -p "Apply rules? (y/n): " r
        [[ $r == "y" ]] && rules_opt="--rules"
    fi

    # Threads
    read -p "CPU threads (empty = auto): " threads
    fork_opt=""; [ -n "$threads" ] && fork_opt="--fork=$threads"

    # Session
    read -p "Resume session? (y/n): " resume
    session_opt=""; [ "$resume" == "y" ] && session_opt="--session=brute_session"

    # FINAL JOHN COMMAND (fixed!)
    cmd="john --format=$format $hash_file"
    [[ "$attack_type" == "1" ]] && cmd="$cmd --wordlist=$wordlist $rules_opt"
    [[ "$attack_type" == "2" ]] && cmd="$cmd $mask_opt $extra_args"
    [[ "$attack_type" == "3" ]] && cmd="$cmd --wordlist=$wordlist $mask_opt $extra_args"
    [[ "$attack_type" == "4" ]] && cmd="$cmd $extra_args"

    cmd="$cmd $fork_opt $session_opt --progress-every=60"

    echo
    echo "Running:"
    echo "$cmd"
    echo
    $cmd

    echo
    echo "Cracked passwords:"
    john --show $hash_file

    [[ "$target_type" != "1" ]] && rm -f "$hash_file"

# ═══════════════════════════════════════════════════════════
# 3) PURE PYTHON (educational)
# ═══════════════════════════════════════════════════════════
elif [ "$tool_choice" == "3" ]; then
    python_script=$(mktemp /tmp/brutepy.XXXXXX.py)
    cat << 'EOF' > "$python_script"
import os, hashlib, zipfile, itertools, time, multiprocessing as mp
try: import rarfile
except: rarfile = None

def try_pass(target_type, target, pwd):
    if target_type == 'md5':
        return hashlib.md5(pwd.encode()).hexdigest() == target.lower()
    elif target_type == 'zip':
        try:
            with zipfile.ZipFile(target) as zf:
                zf.extractall(pwd=pwd.encode())
            return True
        except: return False
    elif target_type == 'rar' and rarfile:
        try:
            with rarfile.RarFile(target) as rf:
                rf.extractall(pwd=pwd.encode())
            return True
        except: return False
    return False

print("Python Brute-Forcer")
type = input("md5 / zip / rar: ").lower()
file = input("File: ")
if not os.path.isfile(file): exit("File not found")

if type == 'md5':
    with open(file) as f: hash = f.read().strip()
else: hash = file

attack = input("1=wordlist 2=mask: ")
if attack == '1':
    wl = input("Wordlist (enter for rockyou): ") or "/usr/share/wordlists/rockyou.txt"
    start = time.time()
    with open(wl, encoding="latin-1") as f:
        for i, line in enumerate(f, 1):
            pwd = line.strip()
            if try_pass(type, hash, pwd):
                print(f"\nFOUND: {pwd}")
                exit()
            if i % 10000 == 0:
                print(f"Tried {i} passwords ({time.time()-start:.1f}s)")
else:
    chars = ""
    chars += "abcdefghijklmnopqrstuvwxyz" if input("Lower? y/n: ") == "y" else ""
    chars += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" if input("Upper? y/n: ") == "y" else ""
    chars += "0123456789" if input("Digits? y/n: ") == "y" else ""
    chars += "!@#$%^&*()_+" if input("Special? y/n: ") == "y" else ""
    min_l, max_l = int(input("Min length: ")), int(input("Max length: "))
    print("Warning: This can take YEARS. Ctrl+C to stop.")

    def worker(length):
        for combo in itertools.product(chars, repeat=length):
            pwd = ''.join(combo)
            if try_pass(type, hash, pwd):
                print(f"\nFOUND: {pwd}")
                os._exit(0)

    start = time.time()
    for length in range(min_l, max_l+1):
        print(f"Trying length {length}...")
        processes = []
        for _ in range(os.cpu_count()):
            p = mp.Process(target=worker, args=(length,))
            p.start()
            processes.append(p)
        for p in processes: p.join()
        if any(not p.is_alive() for p in processes): break

print("Not found.")
EOF
    python3 "$python_script"
    rm -f "$python_script"
else
    echo "Invalid choice"
    exit 1
fi

echo
echo "Done. Have a nice day!"
