#!/bin/bash

# ---------------------------------------------------------
# KALI LINUX MULTI-SCREENSAVER INSTALLER
# No external dependencies. Pure Python Curses.
# ---------------------------------------------------------

# Colors for installer
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Check for Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./install_custom.sh${NC}"
  exit
fi

echo -e "${BLUE}[*] Initializing Multi-Screensaver Installer...${NC}"

# 2. Dependency Check
echo -e "${BLUE}[*] Checking Python environment...${NC}"
apt-get install -y python3 python3-curses -qq > /dev/null 2>&1

# 3. Create the Python Script
echo -e "${BLUE}[*] Compiling Python Engine into /usr/local/bin/scr ...${NC}"

cat << 'PYTHON_EOF' > /usr/local/bin/scr
#!/usr/bin/env python3
import curses
import random
import time
import math

# --- SHARED UTILS ---
def init_colors():
    curses.start_color()
    curses.use_default_colors()
    # Matrix Colors
    curses.init_pair(1, curses.COLOR_GREEN, -1)
    curses.init_pair(2, curses.COLOR_WHITE, -1) # Bright head
    # Space Colors
    curses.init_pair(3, curses.COLOR_YELLOW, -1) 
    curses.init_pair(4, curses.COLOR_CYAN, -1)
    # Retro Colors
    curses.init_pair(5, curses.COLOR_RED, -1)
    curses.init_pair(6, curses.COLOR_MAGENTA, -1)

def check_exit(stdscr):
    # Returns True if user pressed a key
    stdscr.nodelay(1)
    ch = stdscr.getch()
    if ch != -1:
        return True
    return False

# --- MODE 1: CYBER RAIN ---
def run_matrix(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    drops = []
    chars = "0123456789abcdefABCDEF<>/\\"

    # Init drops
    for _ in range(int(max_x / 2)):
        drops.append([random.randint(0, max_x-1), random.randint(0, max_y-1), random.uniform(0.1, 0.4)])

    while True:
        if check_exit(stdscr): break
        
        # Handle Resize
        if (curses.LINES, curses.COLS) != (max_y, max_x):
            max_y, max_x = stdscr.getmaxyx()
            stdscr.clear()
            drops = []

        # Logic
        for drop in drops:
            x, y, speed = drop
            draw_y = int(y)
            
            # Draw Head (White)
            if 0 <= draw_y < max_y:
                try:
                    stdscr.addch(draw_y, x, random.choice(chars), curses.color_pair(2) | curses.A_BOLD)
                except: pass

            # Draw Tail (Green)
            if 0 <= draw_y - 1 < max_y:
                try:
                    stdscr.addch(draw_y - 1, x, random.choice(chars), curses.color_pair(1))
                except: pass
            
            # Erase far tail
            if 0 <= draw_y - 10 < max_y:
                try:
                    stdscr.addch(draw_y - 10, x, " ")
                except: pass

            # Update
            drop[1] += drop[2]
            if drop[1] - 10 > max_y:
                drop[1] = 0
                drop[0] = random.randint(0, max_x - 1)

        # Add random new drops
        if len(drops) < max_x and random.random() > 0.9:
            drops.append([random.randint(0, max_x-1), 0, random.uniform(0.1, 0.4)])

        stdscr.refresh()
        time.sleep(0.03)

# --- MODE 2: WARP SPEED (STARS) ---
def run_stars(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    # Star: [angle, distance, char]
    stars = []
    center_y, center_x = max_y // 2, max_x // 2

    while True:
        if check_exit(stdscr): break

        # Resize check
        if (curses.LINES, curses.COLS) != (max_y, max_x):
            max_y, max_x = stdscr.getmaxyx()
            center_y, center_x = max_y // 2, max_x // 2
            stdscr.clear()

        stdscr.clear() # Space needs clearing unlike Matrix

        # Add new stars
        if len(stars) < 100:
            angle = random.uniform(0, 2 * math.pi)
            dist = 2
            stars.append([angle, dist, "."])

        new_stars = []
        for s in stars:
            angle, dist, char = s
            
            # Calculate screen pos
            # x is doubled to account for terminal aspect ratio (chars are tall)
            scr_x = int(center_x + math.cos(angle) * dist * 2) 
            scr_y = int(center_y + math.sin(angle) * dist)

            if 0 <= scr_x < max_x and 0 <= scr_y < max_y:
                color = curses.color_pair(2)
                if dist > 15: color = curses.color_pair(3) # Yellow closer
                if dist > 25: color = curses.color_pair(4) | curses.A_BOLD # Cyan close

                try:
                    stdscr.addch(scr_y, scr_x, "*", color)
                except: pass
                
                # Move star closer (accelerate as it gets closer)
                s[1] += 0.5 + (s[1] * 0.05) 
                new_stars.append(s)
        
        stars = new_stars
        stdscr.refresh()
        time.sleep(0.03)

# --- MODE 3: BOUNCING LOGO ---
def run_bounce(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    x, y = max_x // 2, max_y // 2
    dx, dy = 1, 1
    color_idx = 1
    text = " J04ER "

    while True:
        if check_exit(stdscr): break
        
        # Resize check
        curr_y, curr_x = stdscr.getmaxyx()
        if (curr_y, curr_x) != (max_y, max_x):
            max_y, max_x = curr_y, curr_x
            stdscr.clear()
            x, y = max_x // 2, max_y // 2 # Reset center

        # Erase old
        try:
            stdscr.addstr(y, x, " " * len(text))
        except: pass

        # Move
        x += dx
        y += dy

        # Bounce X
        if x <= 0 or x + len(text) >= max_x:
            dx *= -1
            color_idx = random.randint(1, 6)
        
        # Bounce Y
        if y <= 0 or y >= max_y:
            dy *= -1
            color_idx = random.randint(1, 6)

        # Draw New
        try:
            stdscr.addstr(y, x, text, curses.color_pair(color_idx) | curses.A_BOLD)
        except: pass

        stdscr.refresh()
        time.sleep(0.05)

# --- MENU SYSTEM ---
def main_menu(stdscr):
    curses.curs_set(0)
    init_colors()
    
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        # Draw Menu
        title = "SELECT SCREENSAVER"
        options = ["[1] Cyber Rain", "[2] Warp Speed", "[3] DVD Bounce", "[Q] Quit"]
        
        start_y = h // 2 - 4
        stdscr.addstr(start_y, w//2 - len(title)//2, title, curses.color_pair(2) | curses.A_BOLD)
        
        for idx, opt in enumerate(options):
            stdscr.addstr(start_y + 2 + idx, w//2 - len(opt)//2, opt, curses.color_pair(4))

        stdscr.refresh()
        
        # Wait for input
        stdscr.nodelay(0)
        key = stdscr.getch()

        if key == ord('1'):
            stdscr.clear()
            run_matrix(stdscr)
        elif key == ord('2'):
            stdscr.clear()
            run_stars(stdscr)
        elif key == ord('3'):
            stdscr.clear()
            run_bounce(stdscr)
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
echo "  MULTI-SCREENSAVER INSTALLED"
echo "========================================="
echo -e "${NC}"
echo -e "Command created: ${YELLOW}scr${NC}"
echo -e "Type 'scr' to launch the menu."
echo -e "Press '1', '2', or '3' to choose."
echo -e "Press any key inside a screensaver to return."