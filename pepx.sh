#!/bin/bash

# ============================================================
# Kali "Unrestricted" PEP 668 Bypass Launcher (LITE EDITION)
# Installs the command: sudo pepx
# Features: persistent home, BASIC ONLY, NO TOOLS, auto-update
# ============================================================

TARGET_BIN="/usr/local/bin/pepx"
IMAGE_NAME="kali-pep-lite"
CONTAINER_NAME="kali_lite_lab"
PERSISTENT_HOME="$HOME/.kali-pep-home"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[-] Please run with sudo ${NC}"
    echo "    sudo $0"
    exit 1
fi

# ----------------------------------------------------------------
# Function: Show help
# ----------------------------------------------------------------
show_help() {
    echo -e "${BLUE}Kali Unrestricted Launcher (pepx) - Lite Edition ${NC}"
    echo "Usage:"
    echo "  sudo pepx              → Launch the container (normal use)"
    echo "  sudo pepx --update     → Rebuild image (Update Python/Pip only)"
    echo "  sudo pepx --clean      → Remove image & persistent home (full reset)"
    echo "  sudo pepx --help       → Show this help"
    exit 0
}

# ----------------------------------------------------------------
# Handle arguments
# ----------------------------------------------------------------
case "$1" in
    --update|-u)  REBUILD=true ;;
    --clean|-c)   CLEAN=true ;;
    --help|-h|"") : ;;
    *) echo "Unknown option: $1 → use --help" ; exit 1 ;;
esac

# ----------------------------------------------------------------
# Full clean
# ----------------------------------------------------------------
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}[!] Removing image and persistent home... ${NC}"
    docker rmi -f $IMAGE_NAME 2>/dev/null || true
    rm -rf "$PERSISTENT_HOME"
    echo -e "${GREEN}[+] Clean complete. Run the installer again or 'sudo pepx' to rebuild. ${NC}"
    exit 0
fi

# ----------------------------------------------------------------
# Install / update the pepx command itself
# ----------------------------------------------------------------
echo -e "${BLUE}[*] Installing / updating 'pepx' command → ${TARGET_BIN}${NC}"

cat <<'EOF' > "$TARGET_BIN"
#!/bin/bash
# ==== pepx launcher (Lite Edition) ====

IMAGE_NAME="kali-pep-lite"
CONTAINER_NAME="kali_lite_lab"
PERSISTENT_HOME="$HOME/.kali-pep-home"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Must be root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[-] Run with sudo → sudo pepx ${NC}"
    exit 1
fi

# Handle special flags first
case "$1" in
    --update|-u)
        echo -e "${YELLOW}[!] Forcing rebuild of ${IMAGE_NAME} ... ${NC}"
        docker rmi -f $IMAGE_NAME 2>/dev/null || true
        ;;
    --clean|-c)
        echo -e "${YELLOW}[!] Full cleanup requested... ${NC}"
        docker rmi -f $IMAGE_NAME 2>/dev/null || true
        rm -rf "$PERSISTENT_HOME"
        echo -e "${GREEN}[+] Everything removed. Next 'sudo pepx' will rebuild from scratch. ${NC}"
        exit 0
        ;;
    --help|-h)
        echo -e "${BLUE}pepx – Unrestricted Kali (Lite) ${NC}"
        echo "  sudo pepx          → normal launch"
        echo "  sudo pepx --update → rebuild image"
        echo "  sudo pepx --clean  → delete image + persistent home"
        exit 0
        ;;
esac

# Ensure persistent home exists
mkdir -p "$PERSISTENT_HOME"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[-] Docker not found. Install it first: apt install docker.io ${NC}"
    exit 1
fi

# Build image if missing or --update was used
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo -e "${YELLOW}[!] Image not found → building Lite Kali (Fast build)... ${NC}"

    BUILD_DIR=$(mktemp -d)
    cat <<DOCKERFILE > "$BUILD_DIR/Dockerfile"
FROM kalilinux/kali-rolling
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# NO FULL UPGRADE - Only update list and install basics
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    curl wget git vim nano \
    iputils-ping net-tools dnsutils procps tree \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Permanently destroy PEP 668 markers
RUN find /usr/lib/python3* -name EXTERNALLY-MANAGED -exec rm -f {} \; || true

# Nice prompt & aliases
RUN echo "alias ls='ls --color=auto'" >> /root/.bashrc && \\
    echo "alias ll='ls -lah'" >> /root/.bashrc && \\
    echo "alias pip='pip3'" >> /root/.bashrc && \\
    echo "PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;31m\\]kali-lite\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >> /root/.bashrc

WORKDIR /root
CMD ["/bin/bash"]
DOCKERFILE

    docker build --pull --no-cache -t $IMAGE_NAME "$BUILD_DIR"
    BUILD_STATUS=$?
    rm -rf "$BUILD_DIR"

    if [ $BUILD_STATUS -ne 0 ]; then
        echo -e "${RED}[-] Build failed! ${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Lite image built and ready! ${NC}"
fi

# Launch!
echo -e "${GREEN}[+] Starting unrestricted Kali Lite (PEP 668 = dead) ${NC}"
echo -e "    Current host directory mounted → /mnt/host${NC}"
echo -e "    Persistent home → ${PERSISTENT_HOME}${NC}"
echo -e "${BLUE}----------------------------------------------------- ${NC}"

docker run -it --rm \
    --name $CONTAINER_NAME \
    --hostname kali-lite \
    -v "$PERSISTENT_HOME:/root" \
    -v "$(pwd):/mnt/host" \
    -v /dev:/dev --privileged \
    --cap-add=NET_ADMIN --cap-add=SYS_PTRACE \
    $IMAGE_NAME

echo -e "${BLUE}Session ended. Container auto-removed. ${NC}"
EOF

chmod +x "$TARGET_BIN"

# ----------------------------------------------------------------
# Final message
# ----------------------------------------------------------------
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               Installation complete!                         ║"
echo "║                                                              ║"
echo "║  Just type anywhere:   sudo pepx                             ║"
echo "║                                                              ║"
echo "║  This is the LITE version:                                   ║"
echo "║    - No full OS upgrade (fast build)                         ║"
echo "║    - No hacking tools installed (install manually if needed) ║"
echo "║    - PIP is fully unlocked                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Force a first build if image doesn't exist yet
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo -e "${YELLOW}[*] First-time build starting now (takes ~30-60 seconds)... ${NC}"
    sudo pepx --update >/dev/null 2>&1 && echo -e "${GREEN}[+] First build completed! You’re ready to go. ${NC}"
fi

exit 0
