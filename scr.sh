#!/bin/bash

# ---------------------------------------------------------
# FINAL SCREENSAVER INSTALLER (Hourglass Fill Logic Fix)
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

echo -e "${BLUE}[*] Initializing Final Screensaver Suite...${NC}"

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
import math

# --- SHARED UTILS ---
def init_colors():
    curses.start_color()
    curses.use_default_colors()
    curses.curs_set(0) # Hide cursor
    
    # Base Colors
    curses.init_pair(1, curses.COLOR_GREEN, -1)   # Green (Matrix)
    curses.init_pair(2, curses.COLOR_WHITE, -1)   # White (Text/Head) 
    curses.init_pair(3, curses.COLOR_YELLOW, -1)  # Yellow (Sand) 
    curses.init_pair(4, curses.COLOR_CYAN, -1)    # Cyan (Base Box)
    curses.init_pair(5, curses.COLOR_RED, -1)     # Red (Cycle 1)
    curses.init_pair(6, curses.COLOR_MAGENTA, -1) # Magenta (Checker/Cycle 2)
    curses.init_pair(7, curses.COLOR_BLUE, -1)    # Blue (Cycle 3)
    
def check_exit(stdscr):
    stdscr.nodelay(1)
    ch = stdscr.getch()
    if ch != -1:
        return True
    return False

# Safe draw function to help prevent screen shaking on edges
def safe_addstr(stdscr, y, x, string, attr=0):
    h, w = stdscr.getmaxyx()
    if y >= h - 1 or x >= w - 1: return
    
    if x + len(string) >= w:
        string = string[:w - x - 1]
    
    try:
        stdscr.addstr(y, x, string, attr)
    except:
        pass

# --- MODE 1: CLOCK BOX (Color Changing) ---
def run_clock_box(stdscr):
    color_cycle = 4
    colors = [4, 5, 6, 7] # Cyan, Red, Magenta, Blue
    
    while True:
        if check_exit(stdscr): break
        
        max_y, max_x = stdscr.getmaxyx()
        stdscr.clear()
        
        t = datetime.datetime.now().strftime("%H:%M:%S")
        d = datetime.datetime.now().strftime("%Y-%m-%d")
        
        lines = [
            "+" + "-"*20 + "+",
            "|   TIME: {}   |".format(t),
            "|   DATE: {} |".format(d),
            "+" + "-"*20 + "+"
        ]
        
        start_y = (max_y // 2) - 2
        
        current_color = curses.color_pair(colors[color_cycle % len(colors)]) | curses.A_BOLD
        
        for i, line in enumerate(lines):
            start_x = (max_x // 2) - (len(line) // 2)
            safe_addstr(stdscr, start_y + i, start_x, line, current_color)
            
            if i in [1, 2]:
                inner_text = line[1:-1]
                safe_addstr(stdscr, start_y + i, start_x + 1, inner_text, curses.color_pair(2) | curses.A_BOLD)

        stdscr.refresh()
        color_cycle += 1
        time.sleep(1)

# --- MODE 2: BOUNCE TEXT (Color Changing) ---
def run_bounce_text(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    x, y = 3, 3
    dx, dy = 1, 1 
    text = " 🅙̣̣  ⓿̣̣  ❹̣̣  🅔̣̣  🅡̣̣  🎩 "
    color_cycle = 3
    colors = [3, 4, 5, 6] # Yellow, Cyan, Red, Magenta
    
    while True:
        if check_exit(stdscr): break
        
        curr_y, curr_x = stdscr.getmaxyx()
        if (curr_y, curr_x) != (max_y, max_x):
            max_y, max_x = curr_y, curr_x
            stdscr.clear()

        stdscr.clear()
        
        current_color = curses.color_pair(colors[color_cycle % len(colors)]) | curses.A_BOLD
        
        safe_addstr(stdscr, y, x, text, current_color)
            
        x += dx
        y += dy
        
        if x <= 1 or x + len(text) >= max_x - 1: dx *= -1
        if y <= 1 or y >= max_y - 1: dy *= -1
        
        stdscr.refresh()
        
        color_cycle += 1 
        time.sleep(0.05)

# --- MODE 3: MATRIX RAIN ---
def run_matrix_rain(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    drops = [0] * max_x
    chars = "0123456789abcdefABCDEF<>/\\"
    
    while True:
        if check_exit(stdscr): break
        
        curr_y, curr_x = stdscr.getmaxyx()
        if (curr_y, curr_x) != (max_y, max_x):
            max_y, max_x = curr_y, curr_x
            drops = [0] * max_x
            stdscr.clear()
        
        for x in range(max_x - 1):
            if 0 <= drops[x] < max_y:
                try: stdscr.addch(drops[x], x, random.choice(chars), curses.color_pair(2) | curses.A_BOLD)
                except: pass

            if 0 <= drops[x] - 1 < max_y:
                try: stdscr.addch(drops[x] - 1, x, random.choice(chars), curses.color_pair(1))
                except: pass
            
            if 0 <= drops[x] - 10 < max_y:
                try: stdscr.addch(drops[x] - 10, x, " ")
                except: pass
            
            drops[x] += 1
            if drops[x] - 10 > max_y or random.random() > 0.95:
                drops[x] = random.randint(-max_y, 0)

        stdscr.refresh()
        time.sleep(0.05)


# --- MODE 4: HOURGLASS (Realistic Fill Logic) ---
def run_hourglass(stdscr):
    # Total units of sand (Higher is smoother but slower)
    sand_total = 100 
    sand_top = sand_total
    sand_bot = 0
    flip_phase = 0 # 0=Running, 1=Flipping Up, 2=Flipping Down (Reset)
    
    # Constants for drawing the shape
    HW = 14 # Half-Width (Max width of top/bottom)
    HH = 7  # Half-Height (Chamber height)
    
    while True:
        if check_exit(stdscr): break
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        cy, cx = h//2, w//2
        
        # --- LOGIC ---
        if flip_phase == 0:
            if sand_top > 0:
                sand_top -= 1; sand_bot += 1
            else:
                flip_phase = 1
                time.sleep(0.5)
        elif flip_phase == 1:
            sand_top, sand_bot = sand_total, 0
            flip_phase = 2
        elif flip_phase == 2:
            flip_phase = 0
            time.sleep(0.5)

        # --- DRAWING ---
        c_glass = curses.color_pair(4) | curses.A_BOLD
        c_sand = curses.color_pair(3) | curses.A_BOLD
        
        # Draw Frame
        safe_addstr(stdscr, cy - HH, cx - HW, "+" + "-"*(HW*2 - 2) + "+", c_glass)
        safe_addstr(stdscr, cy + HH, cx - HW, "+" + "-"*(HW*2 - 2) + "+", c_glass)
        for i in range(1, HH):
            safe_addstr(stdscr, cy - HH + i, cx - HW + i, "\\", c_glass)
            safe_addstr(stdscr, cy - HH + i, cx + HW - i - 1, "/", c_glass)
            safe_addstr(stdscr, cy + HH - i, cx - HW + i, "/", c_glass)
            safe_addstr(stdscr, cy + HH - i, cx + HW - i - 1, "\\", c_glass)

        # Draw Sand Stream
        if sand_top > 0 and flip_phase == 0:
            safe_addstr(stdscr, cy, cx, "V", c_sand)
            safe_addstr(stdscr, cy+1, cx, "I", c_sand)

        # CALCULATE LEVELS BASED ON SAND COUNT
        
        # 1. Top Chamber (Recedes from top)
        # We need to find which row the sand level is currently on.
        # The top chamber has HH-1 rows of sand. Sand fills up from the bottom (closest to neck).
        
        sand_per_row = (sand_total / HH) # Average distribution
        
        # The total number of rows currently filled with sand
        sand_rows_top = int(sand_top * HH / sand_total)
        
        for i in range(HH):
            # Row index from top: cy - HH + i (i=0 is the cap, i=1 is the first row)
            # The sand recedes (disappears) from the top row (i=1) downwards.
            
            # Sand should only be visible if 'i' is greater than the empty space (HH - sand_rows_top)
            if i < sand_rows_top and i > 0:
                # Calculate width of the sand row (which is the width of the container at that row)
                w_container = (HH - i) * 2
                sand_str = "#" * w_container
                safe_addstr(stdscr, cy - HH + i, cx - w_container // 2, sand_str, c_sand)
            elif i > 0:
                # Draw space to erase old sand, if needed (or rely on clear)
                pass

        # 2. Bottom Chamber (Fills up from neck)
        # The sand appears from the bottom row (cy + HH - 1) upwards.
        sand_rows_bot = int(sand_bot * HH / sand_total)
        
        for i in range(1, HH):
            # Row index from bottom: cy + HH - i
            # The sand is visible if 'i' is less than the filled rows (sand_rows_bot)
            if i <= sand_rows_bot:
                w_container = (i * 2) 
                sand_str = "#" * w_container
                safe_addstr(stdscr, cy + HH - i, cx - w_container // 2, sand_str, c_sand)

        stdscr.refresh()
        time.sleep(0.05) # Increased speed for smoother flow

# --- MODE 5: RAIN DOTS ---
def run_rain_dots(stdscr):
    max_y, max_x = stdscr.getmaxyx()
    cols = [0] * max_x
    
    while True:
        if check_exit(stdscr): break
        
        curr_y, curr_x = stdscr.getmaxyx()
        if (curr_y, curr_x) != (max_y, max_x):
            max_y, max_x = curr_y, curr_x
            cols = [0] * max_x
            stdscr.clear()
        
        stdscr.clear()
        
        for x in range(max_x - 1):
            y = cols[x]
            if 0 <= y < max_y:
                color = curses.color_pair(4) if x % 2 == 0 else curses.color_pair(2)
                try:
                    stdscr.addch(y, x, ".", color)
                except: pass
            
            cols[x] = (cols[x] + random.randint(0,1)) % max_y

        stdscr.refresh()
        time.sleep(0.05)

# --- MODE 6: CHECKER ---
def run_checker(stdscr):
    p = False
    while True:
        if check_exit(stdscr): break
        
        max_y, max_x = stdscr.getmaxyx()
        stdscr.clear()
        
        block = "█ "
        
        for y in range(max_y - 1):
            pattern = (block if (y % 2 == p) else " " + block.strip()) * (max_x // 2 + 1)
            safe_addstr(stdscr, y, 0, pattern, curses.color_pair(6))
            
        p = not p
        stdscr.refresh()
        time.sleep(0.3)

# --- MENU SYSTEM ---
def main_menu(stdscr):
    init_colors()
    
    options = [
        ("[1] Clock Box (Color Cycle)", run_clock_box), 
        ("[2] Bounce Text (Color Cycle)", run_bounce_text), 
        ("[3] Matrix Rain", run_matrix_rain),
        ("[4] Hourglass (Realistic Flip)", run_hourglass),
        ("[5] Rain Dots", run_rain_dots), 
        ("[6] Checker", run_checker)
    ]

    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        title = "=== TERMINAL SCREENSAVER ==="
        
        start_y = h // 2 - 5
        safe_addstr(stdscr, start_y, w//2 - len(title)//2, title, curses.color_pair(3) | curses.A_BOLD)
        
        for idx, (opt, func) in enumerate(options):
            safe_addstr(stdscr, start_y + 2 + idx, w//2 - len(opt)//2, opt, curses.color_pair(2))
        
        safe_addstr(stdscr, start_y + 10, w//2 - 4, "[Q] Quit", curses.color_pair(5))

        stdscr.refresh()
        
        stdscr.nodelay(0)
        key = stdscr.getch()

        if key == ord('1'): options[0][1](stdscr)
        elif key == ord('2'): options[1][1](stdscr)
        elif key == ord('3'): options[2][1](stdscr)
        elif key == ord('4'): options[3][1](stdscr)
        elif key == ord('5'): options[4][1](stdscr)
        elif key == ord('6'): options[5][1](stdscr)
        elif key in [ord('q'), ord('Q')]: break

if __name__ == "__main__":
    try:
        curses.wrapper(main_menu)
    except Exception as e:
        pass 
PYTHON_EOF

# 4. Permissions and Done
chmod +x /usr/local/bin/scr

echo -e "${GREEN}"
echo "========================================="
echo "  SCREENSAVER INSTALLED SUCCESSFULLY"
echo "  Hourglass fill logic updated for realism."
echo "========================================="
echo -e "${NC}"
echo -e "Command created: ${YELLOW}scr${NC}"
echo -e "Type 'scr' to launch the menu."
