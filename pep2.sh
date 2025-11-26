#!/bin/bash

# ============================================================
# Auto-Installer: Debian 11 (Bullseye) Launcher (pep2)
# Base: Debian 11 (No PEP 668 restrictions exist in this OS)
# ============================================================

TARGET_BIN="/usr/local/bin/pep2"
IMAGE_NAME="debian-bullseye-clean"
CONTAINER_NAME="pep2_legacy"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Check for Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[-] Please run with sudo:${NC} sudo ./install_pep2_bullseye.sh"
    exit 1
fi

echo -e "${GREEN}[*] Installing 'pep2' using Debian 11 (Bullseye)...${NC}"

# 2. Auto-Install Docker if missing
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}[!] Docker not found. Installing...${NC}"
    apt-get update && apt-get install -y docker.io
    systemctl enable --now docker
else
    echo -e "${GREEN}[+] Docker is already installed.${NC}"
fi

# 3. Create the 'pep2' script
cat <<'EOF' > "$TARGET_BIN"
#!/bin/bash

IMAGE_NAME="debian-bullseye-clean"
CONTAINER_NAME="pep2_legacy"
PERSISTENT_HOME="$HOME/.pep2-home"

# Ensure Root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo pep2"
    exit 1
fi

# --clean argument to reset everything
if [[ "$1" == "--clean" ]]; then
    docker rmi -f $IMAGE_NAME 2>/dev/null
    rm -rf "$PERSISTENT_HOME"
    echo "[+] Environment cleaned."
    exit 0
fi

mkdir -p "$PERSISTENT_HOME"

# Check/Build Image
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "[*] Building Debian 11 Base (Natively Unrestricted)..."
    
    BUILD_DIR=$(mktemp -d)
    
    # We use debian:bullseye-slim because it predates PEP 668
    cat <<DOCKERFILE > "$BUILD_DIR/Dockerfile"
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Python and basics
# No need for removal hacks because Bullseye doesn't have the lock file!
RUN apt-get update && apt-get install -y \\
    python3 python3-pip python3-venv \\
    curl wget git vim nano iputils-ping net-tools procps \\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo "alias pip=pip3" >> /root/.bashrc
RUN echo "PS1='\[\033[01;32m\]debian11-pep2\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /root/.bashrc

WORKDIR /root
CMD ["/bin/bash"]
DOCKERFILE

    docker build -t $IMAGE_NAME "$BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

# Run
docker run -it --rm \
    --name $CONTAINER_NAME \
    --hostname debian11 \
    -v "$PERSISTENT_HOME:/root" \
    -v "$(pwd):/mnt/host" \
    $IMAGE_NAME
EOF

chmod +x "$TARGET_BIN"

echo -e "${GREEN}[+] Done! usage:${NC}"
echo -e "   ${YELLOW}sudo pep2${NC}"
