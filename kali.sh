#!/bin/bash

# ============================================================
#   Kali Linux Auto-Docker Setup - TERMINAL SELECT MENU
# ============================================================

# 1. Check for Root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (sudo ./install_kali_docker.sh)"
  exit 1
fi

# 2. Define the Hourglass/Spinner Function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    tput civis # Hide cursor
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] Working..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    printf "    Done!    \n"
    tput cnorm # Restore cursor
}

# 3. Helper: Create the "kali" shortcut command
create_shortcut() {
    local img_name=$1
    echo "Creating 'kali' terminal shortcut..."
    
    # Creates an executable script in /usr/local/bin
    cat <<EOF > /usr/local/bin/kali
#!/bin/bash
echo "Starting Kali Linux (\$img_name)..."
docker run -it --rm \\
  --hostname kali \\
  --net host \\
  --env TERM=xterm-256color \\
  -v \$HOME:/root/host_home \\
  $img_name
EOF

    chmod +x /usr/local/bin/kali
    echo -e "\n\033[1;32mShortcut created! You can now just type 'kali' to start.\033[0m"
}

# 4. Check Dependencies
echo "Checking system requirements..."

# Whiptail is no longer checked for or installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    (apt-get update -y && apt-get install -y docker.io) & 
    spinner $!
    systemctl enable --now docker
else
    echo "Docker is installed."
fi

# 5. Display the Terminal Selection Menu (Bash 'select')
echo -e "\n\033[1;33m*** Kali Docker Installer ***\033[0m"
echo "Select your Kali Linux Docker Setup:"

OPTIONS=(
    "Light (Essential tools, Colors, Nano - Fast)" 
    "Default (Standard Kali Toolset - Slower)" 
    "Full (Everything - Very Slow)"
)

select choice_text in "${OPTIONS[@]}" "Exit"; do
    case $choice_text in
        "Light (Essential tools, Colors, Nano - Fast)")
            CHOICE=1
            break
            ;;
        "Default (Standard Kali Toolset - Slower)")
            CHOICE=2
            break
            ;;
        "Full (Everything - Very Slow)")
            CHOICE=3
            break
            ;;
        "Exit")
            echo "Installation cancelled by user."
            exit 0
            ;;
        *)
            echo "Invalid selection. Please enter the number next to your choice."
            ;;
    esalac
done

# 6. Build Logic
mkdir -p kali_build_temp
DOCKERFILE="kali_build_temp/Dockerfile"
TARGET_IMG=""
# Common packages for "Normal Look" (Colors, bashrc, nano)
COMMON_PACKAGES="kali-defaults bash-completion nano iproute2 iputils-ping ncurses-term"

case $CHOICE in
    1)
        # --- LIGHT BUILD (Fast) ---
        echo "Building Light Image..."
        TARGET_IMG="my-kali-light"
        
        cat <<EOF > $DOCKERFILE
FROM kalilinux/kali-rolling
ENV TERM xterm-256color
RUN apt-get update && apt-get install -y $COMMON_PACKAGES
RUN echo "export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '" >> /root/.bashrc
EOF
        ;;
        
    2)
        # --- DEFAULT BUILD (Slower) ---
        echo "Building Default Image (kali-linux-default)..."
        TARGET_IMG="my-kali-default"

        cat <<EOF > $DOCKERFILE
FROM kalilinux/kali-rolling
ENV TERM xterm-256color
RUN apt-get update && apt-get install -y kali-linux-default $COMMON_PACKAGES
RUN echo "export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '" >> /root/.bashrc
EOF
        ;;
        
    3)
        # --- FULL UPGRADE BUILD (Slowest) ---
        echo "Building Full Image with full-upgrade..."
        TARGET_IMG="my-kali-full"

        cat <<EOF > $DOCKERFILE
FROM kalilinux/kali-rolling
ENV TERM xterm-256color
RUN apt-get update && apt-get full-upgrade -y && apt-get install -y $COMMON_PACKAGES
RUN echo "export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '" >> /root/.bashrc
EOF
        ;;
esac

# Execute Build
(docker build -t $TARGET_IMG kali_build_temp/) &
spinner $!

# Cleanup
rm -rf kali_build_temp

# Create the shortcut
create_shortcut $TARGET_IMG

# Final Success Message
echo "----------------------------------------------------"
echo -e "\033[1;32mINSTALLATION COMPLETE!\033[0m"
echo "To launch Kali, open a new terminal and type: \033[1;33mkali\033[0m"
echo "----------------------------------------------------"