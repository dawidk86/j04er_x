#!/bin/bash
# PEPINO  – MADE BY J04er
# ============================================================

set -e
clear

echo -e "\033[1;32m"
cat << "EOF"
   _____           _         
  |  __ \         (_)        
  | |__) |__ ___   _ _ __    
  |  ___/ _ \  _ \| | '_ \   
  | |  |  __/ |_) | | | | |  
  | |   \___| .__/|_|_| | |  
  | |      | |        | |    
  |_|      |_|        |_|    
          RED ROOT + WORKING MSFCONSOLE
EOF
echo -e "\033[0m"

# Install Docker
if ! command -v docker &>/dev/null; then
    echo -e "\033[1;33mInstalling Docker...\033[0m"
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null 2>&1
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --quiet
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    systemctl enable --now docker > /dev/null 2>&1
fi

# THE FINAL pepino command
sudo tee /usr/local/bin/pepino > /dev/null <<'EOF'
#!/bin/bash
IMAGE="pepino"
CONTAINER="pepino_bg"
HOME="/opt/pepino-home"
G='\033[0;32m' R='\033[1;31m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'

[ "$EUID" -ne 0 ] && { echo -e "${R}Run with sudo${N}"; exit 1; }

case "$1" in
--reset) docker stop $CONTAINER 2>/dev/null; docker rm $CONTAINER 2>/dev/null; docker rmi -f $IMAGE 2>/dev/null; rm -rf $HOME /opt/.pepino_done; echo -e "${G}Reset complete${N}"; exit 0;;
--delete) docker stop $CONTAINER 2>/dev/null; docker rm $CONTAINER 2>/dev/null; docker rmi -f $IMAGE 2>/dev/null; echo -e "${G}Deleted${N}"; exit 0;;
--back|-b) BACK=1 ;;
esac

mkdir -p $HOME && chmod 700 $HOME

if [[ -z "$(docker images -q $IMAGE 2>/dev/null)" ]] || [[ ! -f /opt/.pepino_done ]]; then
    clear
    echo -e "${C}Pepino  – Choose tools:${N}"
    echo "  1) Metasploit only          ~8 min"
    echo "  2) Nmap + scripts           ~4 min"
    echo "  3) Hydra + rockyou          ~5 min"
    echo "  4) Hashcat tools            ~6 min"
    echo "  5) ALL (recommended)        ~9 min"
    echo "  6) Minimal                  ~2 min"
    echo
    read -p "Choice [1-6] (5): " choice
    choice=${choice:-5}

    echo -e "\n${Y}Grab a cup of coffee ⌛ This can take some times ⌛${N}"
    echo -e "${Y}Grab a BIG coffee${N}\n"

    # Real spinning hourglass (works everywhere)
    echo -n " Building Pepino   "
    spin='⌛ ⌚'
    i=0
    while :; do
        printf "\b${spin:i++%${#spin}:1}"
        sleep 0.5
    done &
    SPINNER=$!

    cat <<DOCKERFILE | docker build --build-arg TOOLS=$choice -t $IMAGE -f - .
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive PIP_BREAK_SYSTEM_PACKAGES=1
ARG TOOLS=5

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv build-essential libssl-dev libffi-dev \
    git curl wget vim nano net-tools iputils-ping iptables gnupg ca-certificates \
    $([ "$TOOLS" != "6" ] && echo "nmap hydra hcxdumptool hcxtools hashcat aircrack-ng") \
    && rm -rf /var/lib/apt/lists/*

# Python fixes
RUN pip3 install --no-cache-dir --force-reinstall "setuptools==80.0.0"
RUN pip3 install --no-cache-dir "paramiko>=2.12,<3.5" requests

# RouterSploit
RUN git clone https://github.com/threat9/routersploit.git /opt/routersploit && \
    cd /opt/routersploit && pip3 install --no-cache-dir -r requirements.txt && \
    ln -sf /opt/routersploit/rsf.py /usr/local/bin/rsf

# rockyou for Hydra/Hashcat
RUN if [ "$TOOLS" = "5" ] || [ "$TOOLS" = "3" ]; then \
        mkdir -p /usr/share/wordlists && cd /usr/share/wordlists && \
        curl -L -o rockyou.txt.gz https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt.gz && gunzip -f rockyou.txt.gz; fi

# RED root@pepino prompt + working msfconsole
RUN echo "export PS1='\[\e[1;31m\]root@\[\e[1;33m\]pepino\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '" > /root/.bashrc && \
    echo "alias pip=pip3" >> /root/.bashrc && \
    echo "alias ll='ls -la --color=auto'" >> /root/.bashrc && \
    echo "msfconsole() { docker run --rm -it --network host -v msf-data:/root/.msf4 metasploitframework/metasploit-framework:latest \"\$@\"; }" >> /root/.bashrc

WORKDIR /root
CMD ["tail", "-f", "/dev/null"]
DOCKERFILE

    kill $SPINNER 2>/dev/null
    printf "\n${G}Pepino  built is complete!${N}\n"
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

[[ "$BACK" == "1" ]] && echo -e "${G}Running in background${N}" || \
    { echo -e "${R}root@${Y}pepino${N}:${C}~${N}\$ Welcome, king."; docker exec -it $CONTAINER bash; }
EOF

sudo chmod +x /usr/local/bin/pepino

clear
echo -e "\033[1;32mPEPINO  INSTALLED \033[0m"
echo -e "Run: \033[1;33msudo pepino\033[0m → enter your  kingdom"
echo -e "      \033[1;33msudo pepino --back\033[0m → background"
echo -e "      \033[1;33msudo pepino --reset\033[0m → full rebuild"
echo
echo -e "\nInstallation complete. Type \033[1;33msudo pepino\033[0m and enjoy work."
