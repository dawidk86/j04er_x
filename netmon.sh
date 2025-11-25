#!/bin/bash

# ==========================================
# NetMon Auto-Installer for Kali Linux
# Installs btop and creates 'netmon' shortcut
# ==========================================

# Colors for text
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[*] Initializing NetMon Setup...${NC}"

# 1. Check for Root Privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root.${NC}"
   echo "    Please run: sudo ./setup_netmon.sh"
   exit 1
fi

# 2. Update and Install btop
echo -e "${BLUE}[*] Updating repositories and installing dependencies...${NC}"
apt-get update -qq
if apt-get install -y btop -qq; then
    echo -e "${GREEN}[+] Dependencies installed successfully.${NC}"
else
    echo -e "${RED}[!] Failed to install dependencies. Check your internet connection.${NC}"
    exit 1
fi

# 3. Create the 'netmon' shortcut script
echo -e "${BLUE}[*] Creating 'netmon' shortcut...${NC}"

# Create the wrapper file in /usr/local/bin
cat <<EOF > /usr/local/bin/netmon
#!/bin/bash
# Wrapper to run btop with a specific network focus preset if desired
# Currently launches standard btop which includes nice network graphs

echo "Starting Network Monitor..."
btop
EOF

# 4. Make it executable
chmod +x /usr/local/bin/netmon

# 5. Final Verification
if command -v netmon &> /dev/null; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}[+] Installation Complete!${NC}"
    echo -e "${BLUE}[*] You can now run the monitor from anywhere by typing:${NC}"
    echo -e "\n    netmon\n"
    echo -e "${GREEN}============================================${NC}"
else
    echo -e "${RED}[!] Something went wrong creating the shortcut.${NC}"
fi