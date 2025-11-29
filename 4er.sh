#!/bin/bash

# --- CONFIGURATION ---
DELAY=0.09                # Speed of movement (lower is faster)
TEXT_KALI="J04er 🎩"          # Text below clock

# --- SETUP ---
# Function to cleanup screen and cursor on exit (Ctrl+C)
cleanup() {
    tput cnorm            # Restore cursor
    tput sgr0             # Reset colors
    clear
    exit 0
}
trap cleanup SIGINT       # Catch Ctrl+C

tput civis                # Hide cursor
clear

# --- INITIALIZATION ---
# Get terminal dimensions
WIDTH=$(tput cols)
HEIGHT=$(tput lines)

# Initial position (start near middle)
x=$((WIDTH / 3))
y=$((HEIGHT / 3))

# Initial velocity (direction)
dx=1
dy=1

# Previous coordinates (used to erase old text)
old_x=$x
old_y=$y

# --- MAIN LOOP ---
while true; do
    # 1. Get Current Time
    NOW=$(date +%T)
    LEN_TIME=${#NOW}
    LEN_KALI=${#TEXT_KALI}
    
    # Calculate centering offset for "kali" text relative to time
    OFFSET=$(( (LEN_TIME - LEN_KALI) / 2 ))

    # 2. Update Position
    ((x += dx))
    ((y += dy))

    # 3. Collision Detection (Bouncing off walls)
    # Right wall (subtract length of longest text to prevent wrapping)
    if (( x >= WIDTH - LEN_TIME )); then 
        dx=-1
        x=$((WIDTH - LEN_TIME))
    fi
    
    # Left wall
    if (( x <= 0 )); then 
        dx=1 
        x=0
    fi
    
    # Bottom wall (subtract 1 for the "kali" line below the clock)
    if (( y >= HEIGHT - 2 )); then 
        dy=-1 
        y=$((HEIGHT - 2))
    fi
    
    # Top wall
    if (( y <= 0 )); then 
        dy=1 
        y=0
    fi

    # 4. Erase Old Text (overwrite with spaces)
    # We re-calculate the offset for the old position to ensure we clean 'kali' correctly
    tput cup $old_y $old_x
    printf "%${LEN_TIME}s" " "
    tput cup $((old_y + 1)) $((old_x + OFFSET))
    printf "%${LEN_KALI}s" " "

    # 5. Pick a Random Color
    # ANSI colors 31-37 (Red, Green, Yellow, Blue, Magenta, Cyan, White)
    COLOR=$(( (RANDOM % 7) + 31 ))
    
    # 6. Draw New Text
    echo -ne "\e[1;${COLOR}m"      # Set Bold + Random Color
    
    # Draw Clock
    tput cup $y $x
    echo -n "$NOW"
    
    # Draw "kali" text below
    tput cup $((y + 1)) $((x + OFFSET))
    echo -n "$TEXT_KALI"

    # 7. Update State and Sleep
    old_x=$x
    old_y=$y
    sleep $DELAY
done
