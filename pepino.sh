#!/bin/bash
# PEPINO  – MADE BY J04er (November 27, 2025)
# ============================================================

set -e
clear

echo -e "\033[1;32m"
cat << "EOF"
    _____         _         
   |  __ \       (_)        
   | |__) |__ ___  _ _ __   
   | ___/ _ \ _ \| | '_ \  
   | |  |  __/ |_) | | | | 
   | |  \___| .__/|_|_| | | 
   | |     | |         | |   
   |_|     |_|         |_|   
          RED ROOT PROMPT EDITION
EOF
echo -e "\033[0m"

# Install Docker silently
if ! command -v docker &>/dev/null; then
    echo -e "\033[1;33mInstalling Docker...\033[0m"
    # Note: Using lsb_release is common for Docker install, but ensuring compatibility
    # with the base image used for installation environment (Debian/Ubuntu)
    sudo apt-get update -qq
    sudo apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null 2>&1
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --quiet
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    sudo systemctl enable --now docker > /dev/null 2>&1
fi

# THE PEPINO DOCKER WHERE PEP668 ITS NO ISSUE
sudo tee /usr/local/bin/pepino > /dev/null <<'EOF'
#!/bin/bash
IMAGE="pepino"
CONTAINER="pepino_bg"
HOME="/opt/pepino-home"
G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'

[ "$EUID" -ne 0 ] && { echo -e "${R}Run with sudo${N}"; exit 1; }

case "$1" in
--reset) docker stop $CONTAINER 2>/dev/null; docker rm $CONTAINER 2>/dev/null; docker rmi -f $IMAGE 2>/dev/null; rm -rf $HOME /opt/.pepino_done; echo -e "${G}Reset complete${N}"; exit 0;;
--delete) docker stop $CONTAINER 2>/dev/null; docker rm $CONTAINER 2>/dev/null; docker rmi -f $IMAGE 2>/dev/null; echo -e "${G}Deleted${N}"; exit 0;;
--back|-b) BACK=1 ;;
esac

mkdir -p $HOME && chmod 700 $HOME

# First run = beauty menu
if [[ -z "$(docker images -q $IMAGE 2>/dev/null)" ]] || [[ ! -f /opt/.pepino_done ]]; then
    clear
    echo -e "${C}Pepino  – Choose your tools:${N}"
    echo "  1) Metasploit only           ~7-8 min"
    echo "  2) Nmap + scripts            ~3-4 min"
    echo "  3) Hydra + rockyou           ~3-4 min"
    echo "  4) Hashcat tools             ~6-8 min"
    echo "  5) ALL THE ABOVE             ~9-11 min  (recommended)"
    echo "  6) Minimal                   ~2-3 min"
    echo
    read -p "Choice [1-6] (5): " choice
    choice=${choice:-5}

    case "$choice" in
        1) TIME="7-8 minutes" ; COFFEE="Grab a strong coffee" ;;
        2) TIME="3-4 minutes"   ; COFFEE="Quick break" ;;
        3) TIME="3-4 minutes"   ; COFFEE="Grab a coffee" ;;
        4) TIME="6-8 minutes"  ; COFFEE="Grab a coffee" ;;
        5) TIME="9-11 minutes" ; COFFEE="Grab a BIG coffee" ;;
        6) TIME="2-3 minutes"   ; COFFEE="Almost instant" ;;
    esac

    echo -e "\n${Y}☕ ⌛Grab a cup of coffee⌛! This can take $TIME.${N}"
    echo -e "${Y}$COFFEE.${N}\n"
    
    # Removed unstable spinner logic for stability

    cat <<DOCKERFILE | docker build --build-arg TOOLS=$choice -t $IMAGE -f - .
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive PIP_BREAK_SYSTEM_PACKAGES=1
ARG TOOLS=5

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv build-essential libssl-dev libffi-dev \
    git curl wget vim nano net-tools iputils-ping iptables gnupg ca-certificates \
    $([ "$TOOLS" = "5" ] || [ "$TOOLS" = "2" ] || [ "$TOOLS" = "3" ] || [ "$TOOLS" = "4" ] && echo "nmap hydra hcxdumptool hcxtools hashcat aircrack-ng") \
    && rm -rf /var/lib/apt/lists/*

# Python fixes
RUN pip3 install --no-cache-dir --force-reinstall "setuptools==80.0.0"
RUN pip3 install --no-cache-dir "paramiko>=2.12,<3.5" requests

# RouterSploit (Always installed for minimal function)
RUN git clone https://github.com/threat9/routersploit.git /opt/routersploit && \
    cd /opt/routersploit && pip3 install --no-cache-dir -r requirements.txt && \
    ln -sf /opt/routersploit/rsf.py /usr/local/bin/rsf

# Wordlists
RUN if [ "$TOOLS" = "5" ] || [ "$TOOLS" = "3" ]; then \
        mkdir -p /usr/share/wordlists && cd /usr/share/wordlists && \
        curl -L -o rockyou.txt.gz https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt.gz && gunzip -f rockyou.txt.gz; fi

# --- FIX: Re-add Metasploit installation ---
RUN if [ "$TOOLS" = "5" ] || [ "$TOOLS" = "1" ]; then \
        curl -fsSL https://apt.metasploit.com/metasploit-framework.gpg.key | gpg --dearmor | tee /usr/share/keyrings/metasploit.gpg > /dev/null && \
        echo "deb [signed-by=/usr/share/keyrings/metasploit.gpg] https://apt.metasploit.com/ stable main" > /etc/apt/sources.list.d/metasploit.list && \
        apt-get update && apt-get install -y metasploit-framework; fi

# FIX: Corrected PS1 to use '#' (root prompt) and ensure coloring for the prompt symbol
RUN echo "export PS1='\[\e[01;31m\]root@\[\e[01;33m\]pepino\[\e[0m\]:\[\e[01;34m\]\w\[\e[0m\]\[\e[01;31m\]\#\[\e[0m\] '" > /root/.bashrc && \
    echo "alias pip=pip3" >> /root/.bashrc && \
    echo "alias ll='ls -la --color=auto'" >> /root/.bashrc

WORKDIR /root
CMD ["tail", "-f", "/dev/null"]
DOCKERFILE

    printf "\n${G}Pepino  built – Welcome${N}\n"
    touch /opt/.pepino_done
fi

# Start container
if ! docker ps --quiet --filter name="^${CONTAINER}$" | grep -q .; then
    docker ps -a --quiet --filter name="^${CONTAINER}$" | grep -q . && docker start $CONTAINER || \
        docker run -d --name $CONTAINER --hostname pepino --restart unless-stopped \
            --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=SYS_ADMIN \
            --device=/dev/net/tun:/dev/net/tun --privileged \
            -v "$HOME:/root" -v "/tmp:/mnt/host" $IMAGE > /dev/null
fi

[[ "$BACK" == "1" ]] && echo -e "${G}Running in background – sudo pepino to enter${N}" || \
    { echo -e "${R}root@\033[1;33mpepino${N}:${C}~${N}\# Welcome, king.${N}"; docker exec -it $CONTAINER bash; }
EOF

sudo chmod +x /usr/local/bin/pepino

clear
echo -e "\033[1;32mPEPINO  INSTALLED \033[0m"
echo -e "Run: \033[1;33msudo pepino\033[0m → enter your  kingdom"
echo -e "      \033[1;33msudo pepino --back\033[0m → background"
echo -e "      \033[1;33msudo pepino --reset\033[0m → full rebuild"
echo
echo -e "\nInstallation complete. Type \033[1;33msudo pepino\033[0m and enjoy work."
