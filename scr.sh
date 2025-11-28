#!/bin/bash

# ---------------------------------------------------------
# CUSTOM SCREENSAVER INSTALLER (MODES 2, 3, 7, 9)
# ---------------------------------------------------------

# Colors for installer output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Check for Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./install_screensavers.sh${NC}"
  exit
fi

echo -e "${BLUE}[*] Initializing Custom Screensaver Installer...${NC}"

# 2. Dependency Check
echo -e "${BLUE}[*] Checking Python environment...${NC}"
apt-get install -y python3 python3-curses -qq > /dev/null 2>&1

# 3. Create the Python Script
echo -e "${BLUE}[*] Compiling Python Engine into /usr/local/bin/scr ...${NC}"

cat << 'PYTHON_EOF' > /usr/local/bin/scr
#!/usr/bin/env python3
import curses
import time
import datetime
import random
import os

# --- SHARED UTILS ---
def init_colors():
    curses.start_color()
    curses.use_default_colors()
    curses.curs_set(0) # Hide cursor
    # Colors
    curses.init_pair(1, curses.COLOR_GREEN, -1)
    curses.init_pair(2, curses.COLOR_WHITE, -1) 
    curses.init_pair(3, curses.COLOR_YELLOW, -1) 
    curses.init_pair(4, curses.COLOR_CYAN, -1) # Nice Cyan
    curses.init_pair(5, curses.COLOR_RED, -1)
    curses.init_pair(6, curses.COLOR_MAGENTA, -1)

def check_exit(stdscr):
    stdscr.nodelay(1)
    ch = stdscr.getch()
    if ch != -1:
        return True
    return False

# --- MODE 2: CLOCK BOX  ---
def run_clock_box(stdscr):
    while True:
        if check_exit(stdscr): break
        
        max_y, max_x = stdscr.getmaxyx()
        stdscr.clear()
        
        # Data
        t = datetime.datetime.now().strftime("%H:%M:%S")
        d = datetime.datetime.now().strftime("%Y-%m-%d")
        
        # Layout
        lines = [
            "+" + "-"*20 + "+",
            "|   TIME: {}   |".format(t),
            "|   DATE: {} |".format(d),
            "+" + "-"*20 + "+"
        ]
        
        # Center coordinates
        start_y = (max_y // 2) - (len(lines) // 2)
        
        # Draw with "Nice Color" (Cyan Box, Bold White Text inside)
        for i, line in enumerate(lines):
            start_x = (max_x // 2) - (len(line) // 2)
            if 0 <= start_y + i < max_y and 0 <= start_x < max_x:
                # Color logic: Borders Cyan, Text White
                if i == 0 or i == 3:
                    stdscr.addstr(start_y + i, start_x, line, curses.color_pair(4) | curses.A_BOLD)
                else:
                    # Split string to color borders differently than text
                    stdscr.addstr(start_y + i, start_x, line, curses.color_pair(4) | curses.A_BOLD)
                    # Overwrite the text part with White
                    inner_text = line[1:-1]
                    stdscr.addstr(start_y + i, start_x + 1, inner_text, curses.color_pair(2) | curses.A_BOLD)

        stdscr.refresh()
        time.sleep(1)

# --- MODE 3: BOUNCE TEXT ---
def run_bounce_text(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    x, y = 2, 2
    dx, dy = 1, 1
    text = " ⫷J⫸⫷0⫸⫷4⫸⫷e⫸⫷r⫸ "
    
    while True:
        if check_exit(stdscr): break
        
        # Handle resize
        curr_y, curr_x = stdscr.getmaxyx()
        if (curr_y, curr_x) != (max_y, max_x):
            max_y, max_x = curr_y, curr_x
            stdscr.clear()

        stdscr.clear()
        
        # Draw
        if 0 <= y < max_y and 0 <= x < max_x - len(text):
            stdscr.addstr(y, x, text, curses.color_pair(3) | curses.A_BOLD)
            
        # Move
        x += dx
        y += dy
        
        # Bounce Logic
        if x <= 1 or x + len(text) >= max_x - 1: dx *= -1
        if y <= 1 or y >= max_y - 1: dy *= -1
        
        stdscr.refresh()
        time.sleep(0.05)

# --- MODE 7: RAIN DOTS ---
def run_rain_dots(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    cols = [0] * max_x
    
    while True:
        if check_exit(stdscr): break
        
        # Resize check
        curr_y, curr_x = stdscr.getmaxyx()
        if (curr_y, curr_x) != (max_y, max_x):
            max_y, max_x = curr_y, curr_x
            cols = [0] * max_x
            stdscr.clear()
        
        stdscr.clear()
        
        # Draw logic based on original script
        # Note: Original script clears screen and redraws whole line.
        # In curses we just place the dots at the specific coordinates.
        for x in range(max_x - 1):
            y = cols[x]
            if 0 <= y < max_y:
                # Use Green for matrix vibe, or White for rain
                stdscr.addch(y, x, ".", curses.color_pair(4) if x % 2 == 0 else curses.color_pair(2))
            
            # Update logic from original script
            cols[x] = (cols[x] + random.randint(0,1)) % max_y

        stdscr.refresh()
        time.sleep(0.05)

# --- MODE 9: CHECKER ---
def run_checker(stdscr):
    p = False
    while True:
        if check_exit(stdscr): break
        
        max_y, max_x = stdscr.getmaxyx()
        stdscr.clear()
        
        block = "█ "
        
        for y in range(max_y - 1):
            # Calculate repetition needed to fill width
            pattern = (block if (y % 2 == p) else " " + block.strip()) * (max_x // 2 + 1)
            # Trim to screen width
            pattern = pattern[:max_x-1]
            try:
                stdscr.addstr(y, 0, pattern, curses.color_pair(6)) # Magenta checker
            except: pass
            
        p = not p
        stdscr.refresh()
        time.sleep(0.3)

# --- MENU SYSTEM ---
def main_menu(stdscr):
    init_colors()
    
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        title = "=== TERMINAL SCREENSAVER ==="
        options = [
            "[1] Clock Box (Nice Color)", 
            "[2] Bounce Text", 
            "[3] Rain Dots", 
            "[4] Checker", 
            "[Q] Quit"
        ]
        
        start_y = h // 2 - 4
        # Draw Title
        stdscr.addstr(start_y, w//2 - len(title)//2, title, curses.color_pair(3) | curses.A_BOLD)
        
        # Draw Options
        for idx, opt in enumerate(options):
            stdscr.addstr(start_y + 2 + idx, w//2 - len(opt)//2, opt, curses.color_pair(2))

        stdscr.refresh()
        
        # Wait for input
        stdscr.nodelay(0)
        key = stdscr.getch()

        # Handle Choices
        if key == ord('1'):
            run_clock_box(stdscr)
        elif key == ord('2'):
            run_bounce_text(stdscr)
        elif key == ord('3'):
            run_rain_dots(stdscr)
        elif key == ord('4'):
            run_checker(stdscr)
        elif key in [ord('q'), ord('Q')]:
            break

if __name__ == "__main__":
    try:
        curses.wrapper(main_menu)
    except Exception as e:
        print(f"Error: {e}")
PYTHON_EOF

# 4. Permissions and Done
chmod +x /usr/local/bin/scr

echo -e "${GREEN}"
echo "========================================="
echo "  SCREENSAVER INSTALLED SUCCESSFULLY"
echo "========================================="
echo -e "${NC}"
echo -e "Command created: ${YELLOW}scr${NC}"
echo -e "Type 'scr' to launch the menu."
