#!/bin/bash
# --- COMMENTED LOGO (inserted by logo tool) ---
# [93m
# 
#       ,--.-,   _.---.,_   .--, .-.--,     ,----.               
#      |==' -| .'  - , `.-, |  |=| -\==\ ,-.--` , \  .-.,.---.   
#      |==|- |/ -  ,  ,_\==\|  `-' _|==||==|-  _.-` /==/  `   \  
#    __|==|, |     .=.   |==\     , |==||==|   `.-.|==|-, .=., | 
# ,--.-'\=|- | -  :=; : _|==|`--.  -|==/==/_ ,    /|==|   '='  / 
# |==|- |=/ ,|     `=` , |==|    \_ |==|==|    .-' |==|- ,   .'  
# |==|. /=| -|\ _,    - /==/     |  \==\==|_  ,`-._|==|_  . ,'.  
# \==\, `-' /  `.   - .`=.`       \ /==/==/ ,     //==/  /\ ,  ) 
#  `--`----'     ``--'--'          `--``--`-----`` `--`-`--`--'  
# ➪  ᴊ04ᴇʀ ᴛᴏᴏʟꜱ ➪
# 
# 
# [0m
# --- END COMMENTED LOGO ---

# --- RUNTIME DISPLAY (runs on start) ---
_logo='[93m
      ,--.-,   _.---.,_   .--, .-.--,     ,----.               
     |=='\'' -| .'\''  - , `.-, |  |=| -\==\ ,-.--` , \  .-.,.---.   
     |==|- |/ -  ,  ,_\==\|  `-'\'' _|==||==|-  _.-` /==/  `   \  
   __|==|, |     .=.   |==\     , |==||==|   `.-.|==|-, .=., | 
,--.-'\''\=|- | -  :=; : _|==|`--.  -|==/==/_ ,    /|==|   '\''='\''  / 
|==|- |=/ ,|     `=` , |==|    \_ |==|==|    .-'\'' |==|- ,   .'\''  
|==|. /=| -|\ _,    - /==/     |  \==\==|_  ,`-._|==|_  . ,'\''.  
\==\, `-'\'' /  `.   - .`=.`       \ /==/==/ ,     //==/  /\ ,  ) 
 `--`----'\''     ``--'\''--'\''          `--``--`-----`` `--`-`--`--'\''  
➪  ᴊ04ᴇʀ ᴛᴏᴏʟꜱ ➪

[0m'
printf "%s\n" "$_logo"
sleep 3
# --- END RUNTIME ---

# ===============================================
# Ultimate Installer for your tools + xp & logo folders
# Run as: sudo bash this_script.sh
# ===============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting installation of all tools...${NC}"

# ——————— 1. Install individual scripts to /bin ———————
echo -e "${YELLOW}Installing individual scripts to /bin/...${NC}"

scripts=(
    "ap.sh:ap"
    "bf.sh:bf"
    "bin.sh:bin"
    "clt.sh:clt"
    "ipe.py:ipe"
    "ipl.sh:ipl"
    "netmon.sh:netmon"
    "pep.sh:pep"
    "pep2.sh:pep2"
    "pepx.sh:pepx"
    "scr.sh:scr"
    "clk.sh:clk"
    "iph.py:iph"
    "dfr.sh:dfr"
    "down.sh:down"
    "tele.sh:tele"
    "4er.sh:4er"
)

for entry in "${scripts[@]}"; do
    src="${entry%%:*}"
    dest="${entry##*:}"
    
    if [[ ! -f "$src" ]]; then
        echo -e "${RED}Warning: $src not found! Skipping...${NC}"
        continue
    fi
    
    echo -e "${GREEN}Installing $src → $dest${NC}"
    sudo cp "$src" "/bin/$dest"
    sudo chmod +x "/bin/$dest"
done

# ——————— 2. Install Python dependencies with pipx ———————
echo -e "${YELLOW}Installing Python dependencies via pipx...${NC}"
sudo pipx install requests --include-deps 2>/dev/null || true
sudo pipx install ipaddress --include-deps 2>/dev/null || true
# Ensure pipx bin is in PATH for current session
export PATH="$HOME/.local/bin:$PATH"
sudo pipx ensurepath || true

# ——————— 3. Install xp and logo folders using your smart installer logic ———————
echo -e "${YELLOW}Installing 'xp' and 'logo' folders as commands...${NC}"

# Embedded install-tool.sh logic (slightly simplified for automation)
install_folder() {
    local folder="$1"
    local default_name="$2"

    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}Error: Directory $folder not found!${NC}"
        return 1
    fi

    # Default tool name = folder name
    tool_name="$default_name"

    # Auto-overwrite if already exists (since we're scripting this)
    if command -v "$tool_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}'$tool_name' already exists. Overwriting...${NC}"
    fi

    opt_dir="/opt/$tool_name"
    wrapper="/usr/local/bin/$tool_name"

    # Find main script
    main_script=""
    for candidate in "main.py" "$tool_name.py" "run.py" "start.py" "bin/main.py"; do
        [[ -f "$folder/$candidate" ]] && main_script="$candidate" && break
    done
    if [[ -z "$main_script" ]]; then
        for candidate in "main.sh" "$tool_name.sh" "start.sh" "run.sh" "bin/main.sh"; do
            [[ -f "$folder/$candidate" ]] && main_script="$candidate" && break
        done
    fi

    if [[ -z "$main_script" ]]; then
        echo -e "${RED}No main script found in $folder! Skipping...${NC}"
        return 1
    fi

    script_type="${main_script##*.}"

    sudo mkdir -p "$opt_dir"
    sudo cp -r "$folder"/* "$opt_dir/" 2>/dev/null || true
    sudo cp -r "$folder"/.* "$opt_dir/" 2>/dev/null || true

    # Detect venv
    venv_path=""
    [[ -f "$opt_dir/venv/bin/activate" ]] && venv_path="$opt_dir/venv"
    [[ -f "$opt_dir/.venv/bin/activate" ]] && venv_path="$opt_dir/.venv"

    if [[ "$script_type" == "py" ]]; then
        if [[ -n "$venv_path" ]]; then
            sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
source "$venv_path/bin/activate"
exec python3 "$opt_dir/$main_script" "\$@"
EOF
        else
            sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
exec python3 "$opt_dir/$main_script" "\$@"
EOF
        fi
    else
        sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
exec "$opt_dir/$main_script" "\$@"
EOF
    fi

    sudo chmod +x "$wrapper"
    echo -e "${GREEN}Successfully installed folder '$folder' as command → $tool_name${NC}"
}

# Install the two folders
install_folder "xp" "xp"
install_folder "logo" "logo"

# ——————— Final message ———————
echo -e "${GREEN}"
echo "=========================================="
echo "     ALL TOOLS INSTALLED SUCCESSFULLY!    "
echo "=========================================="
echo "Individual commands: clk, scr, ap, pep, bf, bin, clt, ipe, netmon, ipl, iph, 4er, dfr, down"
echo "Folder commands:     xp, logo"
echo "Python deps:         requests, ipaddress (via pipx)"
echo "=========================================="
echo -e "${NC}"

exit 0
