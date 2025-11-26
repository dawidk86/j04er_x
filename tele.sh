#!/bin/bash
# Telegram Desktop installer script for Kali Linux
# Run with: sudo bash this-script.sh   (or save and run it)

set -e  # stop on any error

echo "=== Telegram Desktop Installer for Kali Linux ==="

# 1. Create /opt/telegram if not exists
sudo mkdir -p /opt/telegram

# 2. Download the latest official .tar.xz
echo "Downloading latest Telegram Desktop..."
wget -O /tmp/tsetup.tar.xz https://telegram.org/dl/desktop/linux

# 3. Extract directly into /opt/telegram (overwrites old version cleanly)
echo "Extracting..."
sudo tar -xJf /tmp/tsetup.tar.xz --strip-components=1 -C /opt/telegram

# 4. Remove the downloaded archive
rm -f /tmp/tsetup.tar.xz

# 5. Make the binary executable
sudo chmod +x /opt/telegram/Telegram

# 6. Create a small wrapper script so you can run "tele" from anywhere
sudo tee /usr/local/bin/tele > /dev/null << 'EOF'
#!/bin/bash
/opt/telegram/Telegram "$@"
EOF

sudo chmod +x /usr/local/bin/tele

# 7. (Optional but nice) Add desktop entry to applications menu
sudo tee /usr/share/applications/telegram.desktop > /dev/null << EOF
[Desktop Entry]
Name=Telegram Desktop
Comment=Official desktop client for Telegram
Exec=/opt/telegram/Telegram %u
Icon=telegram
Terminal=false
Type=Application
Categories=Network;InstantMessaging;Chat;
MimeType=x-scheme-handler/tg;
StartupWMClass=Telegram
EOF

echo ""
echo "Telegram has been installed successfully!"
echo "→ Launch from menu or simply type:  tele"
echo "→ It will auto-update itself when you open it."

exec bash  # refresh the current shell so the new command is available immediately
