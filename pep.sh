#!/bin/bash

# ============================================================
# Installer for Kali "Unrestricted" Shortcut
# Creates a command 'pep' in /usr/local/bin
# ============================================================

TARGET_BIN="/usr/local/bin/pep"

# Ensure script is run with sudo for permission to write to /usr/local/bin
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this installer with sudo"
  echo "    Usage: sudo ./install_pep.sh"
  exit 1
fi

echo "[*] Installing 'pep' shortcut to $TARGET_BIN..."

# Create the script file inside /usr/local/bin
cat <<'EOF' > "$TARGET_BIN"
#!/bin/bash

IMAGE_NAME="kali-no-pep668"
CONTAINER_NAME="kali_hacklab"

# 1. Check for Docker
if ! command -v docker &> /dev/null; then
    echo "[-] Docker is not installed. Please install docker.io."
    exit 1
fi

# 2. Check if the image exists. If not, BUILD IT.
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "[!] Image '$IMAGE_NAME' not found. Building strictly for the first time..."
    
    BUILD_DIR=$(mktemp -d)
    
    cat <<DOCKERFILE > "$BUILD_DIR/Dockerfile"
FROM kalilinux/kali-rolling
ENV DEBIAN_FRONTEND=noninteractive

# Install basics
RUN apt-get update && apt-get install -y \\
    python3 python3-pip curl wget git vim iputils-ping net-tools \\
    && apt-get clean

# THE FIX: Bypass PEP 668 Globally
ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN find /usr/lib/python3* -name "EXTERNALLY-MANAGED" -exec rm {} \; || true
RUN echo "alias pip=pip3" >> /root/.bashrc

WORKDIR /root
CMD ["/bin/bash"]
DOCKERFILE

    echo "[*] Building Docker image (this may take a minute)..."
    docker build -t $IMAGE_NAME "$BUILD_DIR"
    rm -rf "$BUILD_DIR"
    echo "[+] Build complete."
fi

# 3. Run the Container
echo "[+] Launching Unrestricted Kali..."
echo "    Mounting current directory to: /mnt/host"
echo "-----------------------------------------------------"

# Runs properly with interactive terminal
# Uses --rm so it cleans up the container execution on exit (files in /mnt/host persist)
docker run -it --rm \
    --name $CONTAINER_NAME \
    --hostname kali-unrestricted \
    -v "$(pwd):/mnt/host" \
    $IMAGE_NAME
EOF

# Make the new shortcut executable
chmod +x "$TARGET_BIN"

echo "[+] Installation successful!"
echo "-----------------------------------------------------"
echo "USAGE: You can now open a terminal anywhere and type:"
echo "       sudo pep"
echo "-----------------------------------------------------"
