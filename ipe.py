#!/bin/bash

# === ipe - IP & HTTP Link Extractor Auto-Installer ===
# Run this script to install 'ipe' globally

set -e  # Exit on any error

SCRIPT_NAME="ipe"
INSTALL_DIR="/usr/local/bin"
DESKTOP_SCRIPT="$INSTALL_DIR/$SCRIPT_NAME"
PYTHON_SCRIPT_CONTENT='import sys
import os
import re
from urllib.parse import urlparse
import ipaddress

IP_FILENAME = "ex_ip.txt"
HTTP_FILENAME = "ex_http.txt"

def is_ip_address(domain):
    try:
        ipaddress.ip_address(domain)
        return True
    except ValueError:
        return False

def extract_data_from_sources(sources, output_dir):
    print(f"Starting extraction...")
    print(f"Output directory set to: {output_dir}")
    unique_ips = set()
    unique_links = set()
    IP_PATTERN = r'\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?::[0-9]+)?\b'
    HTTP_PATTERN = r'https?://[^\s]+'

    for full_path in sources:
        if not os.path.isfile(full_path):
            continue
        print(f"Processing: {os.path.basename(full_path)}")
        try:
            with open(full_path, 'r', encoding="utf-8", errors="ignore") as f:
                content = f.read()

            unique_ips.update(re.findall(IP_PATTERN, content))
            raw_links = re.findall(HTTP_PATTERN, content)

            for link in raw_links:
                try:
                    parsed = urlparse(link)
                    host = parsed.hostname
                    if host and not is_ip_address(host):
                        unique_links.add(link.strip())
                except:
                    continue
        except Exception as e:
            print(f"Error reading {full_path}: {e}")

    ip_path = os.path.join(output_dir, IP_FILENAME)
    http_path = os.path.join(output_dir, HTTP_FILENAME)

    try:
        with open(ip_path, "w") as f:
            for ip in sorted(unique_ips):
                f.write(ip + "\n")
        with open(http_path, "w") as f:
            for link in sorted(unique_links):
                f.write(link + "\n")
    except PermissionError:
        print(f"Permission denied writing to {output_dir}. Try running with sudo or choose a writable folder.")
        sys.exit(1)

    print("---")
    print("✅ Extraction complete!")
    print(f"IPs saved to: {ip_path}")
    print(f"Links saved to: {http_path}")

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  ipe -i <folder>        → Extract from all files in folder")
        print("  ipe <file>             → Extract from single file")
        print("  ipe --uninstall        → Remove ipe from system")
        sys.exit(1)

    if sys.argv[1] == "--uninstall":
        echo "Removing $DESKTOP_SCRIPT..."
        sudo rm -f "$DESKTOP_SCRIPT"
        echo "✅ ipe has been uninstalled."
        exit 0

    sources = []
    output_dir = ""

    if len(sys.argv) == 3 and sys.argv[1] == "-i":
        folder = os.path.abspath(sys.argv[2])
        if not os.path.isdir(folder):
            print(f"Error: Folder not found: {folder}")
            sys.exit(1)
        output_dir = folder
        for f in os.listdir(folder):
            fp = os.path.join(folder, f)
            if os.path.isfile(fp):
                sources.append(fp)
    elif os.path.isfile(sys.argv[1]):
        fp = os.path.abspath(sys.argv[1])
        sources.append(fp)
        output_dir = os.path.dirname(fp)
    else:
        print("Error: Invalid usage. See help above.")
        sys.exit(1)

    if not sources:
        print("No files to process.")
        sys.exit(0)

    extract_data_from_sources(sources, output_dir)

if __name__ == "__main__":
    main()
'

echo "========================================"
echo "   Installing 'ipe' - IP & Link Extractor"
echo "========================================"

# Check for sudo
if [[ $EUID -ne 0 && ! -w "$INSTALL_DIR" ]]; then
    echo "This script needs sudo to install ipe to $INSTALL_DIR"
    sudo -v || exit 1
fi

# Write the Python script with proper shebang
echo "Installing $SCRIPT_NAME command..."

cat > /tmp/ipe_temp.py << EOF
#!/usr/bin/env python3
$PYTHON_SCRIPT_CONTENT
EOF

# Make executable and move to bin
sudo mv /tmp/ipe_temp.py "$DESKTOP_SCRIPT"
sudo chmod +x "$DESKTOP_SCRIPT"

echo "✅ 'ipe' installed successfully!"
echo ""
echo "Usage:"
echo "   ipe -i /path/to/folder        → Process all files in folder"
echo "   ipe /path/to/file.txt         → Process single file"
echo "   ipe --uninstall               → Remove ipe completely"
echo ""
echo "Output files will be created as:"
echo "   ex_ip.txt     → Extracted IP addresses"
echo "   ex_http.txt   → Clean HTTP/S links (no IP hosts)"
echo ""
echo "You can now run 'ipe' from any directory! 🎉"
