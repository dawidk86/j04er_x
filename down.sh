#!/bin/bash

# ==========================================
# Master Auto-Installer (Port Prompt Removed)
# ==========================================

# 1. Check for Root/Sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root. Usage: sudo ./install_tool.sh"
  exit
fi

echo "Starting installation..."

# 2. Install wget if missing
if ! command -v wget &> /dev/null; then
    echo "Installing wget..."
    apt-get update && apt-get install -y wget
fi

# 3. Create the 'down' script
cat << 'EOF' > /usr/local/bin/down
#!/bin/bash
clear
echo "=========================================="
echo "    Apache/Web Server Bulk Downloader"
echo "=========================================="
echo ""

# --- Prompt 1: Target IP/URL (Port should be included here if needed) ---
read -p "1. Enter target IP or URL (e.g., 192.168.1.5:8080 or example.com): " TARGET_BASE

# TARGET_BASE is now set directly by the user's input (Prompt 1)

# Final URL construction (handles http/https prefix and defaults if missing)
if [[ "$TARGET_BASE" != http* ]]; then
    TARGET_URL="http://$TARGET_BASE/"
else
    TARGET_URL="$TARGET_BASE"
fi

# --- Prompt 2: File Type ---
echo ""
echo "2. What file type? (e.g., pdf, jpg, zip)"
read -p "    Extension: " FILE_EXT

# --- Prompt 3: Quota Limit ---
echo ""
echo "3. Max Download Limit? (Stop after this amount)"
read -p "    (e.g., 500m or 0 for unlimited): " QUOTA_INPUT

if [ "$QUOTA_INPUT" != "0" ] && [ ! -z "$QUOTA_INPUT" ]; then
    QUOTA_OPT="-Q $QUOTA_INPUT"
else
    QUOTA_OPT=""
fi

# --- Prompt 4: Folder ---
echo ""
read -p "4. Folder name to save files (default: 'downloads'): " OUT_DIR
[ -z "$OUT_DIR" ] && OUT_DIR="downloads"
mkdir -p "$OUT_DIR"

# --- Set up Log File ---
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$OUT_DIR/log_$TIMESTAMP.txt"

# --- Prompt 5: Recursive ---
echo ""
read -p "5. Recursive? (Check sub-folders?) [y/n]: " RECURSIVE
if [[ "$RECURSIVE" =~ ^[Yy]$ ]]; then
    RECURSIVE_OPT="-r -l 2" 
else
    RECURSIVE_OPT=""
fi

# --- Prompt 6: Simulation/Test Mode ---
echo ""
read -p "6. Is this a TEST run? (Simulate only - no download) [y/n]: " IS_TEST
if [[ "$IS_TEST" =~ ^[Yy]$ ]]; then
    TEST_OPT="--spider"
    echo "------------------------------------------"
    echo "!!! SIMULATION MODE ACTIVE !!!"
    echo "Logging found files to: $LOG_FILE"
else
    TEST_OPT=""
fi

echo "------------------------------------------"
echo " Starting Job..."
echo " Target:  $TARGET_URL"
echo " Type:    *.$FILE_EXT"
echo " Logfile: $LOG_FILE"
echo "------------------------------------------"

# Execute Wget
# -a: Append output to log file
# -np -nd: Safety flags (No Parent, No Directories)
wget $RECURSIVE_OPT \
     $QUOTA_OPT \
     $TEST_OPT \
     -np -nd \
     -a "$LOG_FILE" \
     --show-progress \
     -A "*.$FILE_EXT" \
     -P "$OUT_DIR" \
     -e robots=off \
     "$TARGET_URL"

echo ""
echo "=========================================="
echo "Job Complete."
echo "Files saved in: ./$OUT_DIR/"
echo "Log saved at:    $LOG_FILE"
echo "=========================================="
read -p "Press Enter to exit..."
EOF

# 4. Make it executable
chmod +x /usr/local/bin/down
echo "✔ Terminal command 'down' updated."

# 5. Update Desktop Shortcut
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd $REAL_USER | cut -d: -f6)
DESKTOP_DIR="$USER_HOME/Desktop"

if [ -d "$DESKTOP_DIR" ]; then
    cat << EOF > "$DESKTOP_DIR/Downloader.desktop"
[Desktop Entry]
Version=1.0
Name=Downloader Tool
Comment=Run the Downloader Script
Exec=/usr/local/bin/down
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Utility;
EOF
    chown $REAL_USER:$REAL_USER "$DESKTOP_DIR/Downloader.desktop"
    chmod +x "$DESKTOP_DIR/Downloader.desktop"
    echo "✔ Desktop shortcut updated."
fi

echo "Installation Complete."
