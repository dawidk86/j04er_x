#!/usr/bin/env python3

"""
logo – Insert or Remove coloured ASCII logo in scripts
Features:
  • Auto-install on first run (to ~/bin/logo)
  • Insert logo with specific ANSI colours (-i)
  • Remove previously inserted logos cleanly (-r)
  • Backup of original file (unless --no-save-orig)
  • Runtime display of logo for 3 seconds on script start
"""

import argparse
import getpass
import os
import re
import shutil
import sys
import time
from pathlib import Path
from typing import Dict, Optional, Tuple

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
ASCII_FILE = Path(__file__).parent / "ascii.txt"  # Place file next to this script

# ANSI colour codes (foreground only)
COLORS: Dict[str, Tuple[str, str]] = {
    '1': ('\033[31m', 'Red'),
    '2': ('\033[32m', 'Green'),
    '3': ('\033[33m', 'Yellow'),
    '4': ('\033[34m', 'Blue'),
    '5': ('\033[35m', 'Magenta'),
    '6': ('\033[36m', 'Cyan'),
    '7': ('\033[37m', 'White'),
    '8': ('\033[91m', 'Bright Red'),
    '9': ('\033[92m', 'Bright Green'),
    '10': ('\033[93m', 'Bright Yellow'),
    '11': ('\033[94m', 'Bright Blue'),
    '12': ('\033[95m', 'Bright Magenta'),
    '13': ('\033[96m', 'Bright Cyan'),
    '14': ('\033[97m', 'Bright White'),
    '0': ('', 'Default (No colour)'),
}
RESET = '\033[0m'

# Markers used to identify inserted code
MARKER_COMMENT_START = "--- COMMENTED LOGO (inserted by logo tool) ---"
MARKER_COMMENT_END = "--- END COMMENTED LOGO ---"
MARKER_RUNTIME_START = "--- RUNTIME DISPLAY (runs on start) ---"
MARKER_RUNTIME_END = "--- END RUNTIME ---"

# ----------------------------------------------------------------------
# Runtime wrapper templates
# ----------------------------------------------------------------------
RUNTIME_TEMPLATES = {
    'python': '''\
import sys
import time
_logo = """{colour}
{logo}
{reset}"""
print(_logo, flush=True)
time.sleep(3)
''',
    'bash': '''\
_logo='{colour}{logo}{reset}'
printf "%s\\n" "$_logo"
sleep 3
''',
    'perl': '''\
use Time::HiRes qw(sleep);
my $_logo = '{colour}{logo}{reset}';
print $_logo;
sleep(3);
''',
    'ruby': '''\
_logo = '{colour}{logo}{reset}'
print _logo
sleep 3
''',
    'javascript': '''\
const _logo = '{colour}{logo}{reset}';
process.stdout.write(_logo + '\\n');
const start = Date.now();
while (Date.now() - start < 3000) {}
''',
    'unknown-shebang': '',
    'unknown': '',
}

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------
def clear_screen() -> None:
    os.system('clear')

def load_ascii_logos(file_path: Path) -> dict:
    """Read logos from file. Each logo starts with '<number>.'"""
    if not file_path.exists():
        print(f"[!] ASCII file not found: {file_path}")
        sys.exit(1)

    logos, cur_num, cur_lines = {}, None, []
    with file_path.open('r', encoding='utf-8') as f:
        for raw in f:
            line = raw.rstrip('\n')
            m = re.match(r'^\s*(\d+)\.\s*$', line)
            if m:
                if cur_num is not None and cur_lines:
                    logos[cur_num] = '\n'.join(cur_lines)
                cur_num = m.group(1)
                cur_lines = []
                continue
            if cur_num is not None:
                cur_lines.append(line)

    if cur_num is not None and cur_lines:
        logos[cur_num] = '\n'.join(cur_lines)
    return logos

def detect_script_type(script_path: Path) -> str:
    """Guess language from shebang or file extension."""
    if not script_path.exists():
        return 'unknown'

    try:
        with script_path.open('r', encoding='utf-8', errors='ignore') as f:
            first = f.readline().strip()
    except Exception:
        first = ""

    if first.startswith('#!'):
        lowered = first.lower()
        if any(x in lowered for x in ('bash', 'sh')):
            return 'bash'
        if 'python' in lowered:
            return 'python'
        if 'perl' in lowered:
            return 'perl'
        if 'ruby' in lowered:
            return 'ruby'
        if any(x in lowered for x in ('node', 'javascript')):
            return 'javascript'
        return 'unknown-shebang'

    ext = script_path.suffix.lower()
    mapping = {'.sh': 'bash', '.py': 'python', '.pl': 'perl',
               '.rb': 'ruby', '.js': 'javascript'}
    return mapping.get(ext, 'unknown')

def comment_prefix(lang: str) -> str:
    return {'python': '# ', 'bash': '# ', 'perl': '# ',
            'ruby': '# ', 'javascript': '// '}.get(lang, '# ')

# ----------------------------------------------------------------------
# Core Logic: Insert & Remove
# ----------------------------------------------------------------------

def remove_logo(content: str) -> Tuple[str, bool]:
    """
    Scans content for start/end markers and removes text between them.
    Returns (new_content, boolean_was_removed).
    """
    lines = content.splitlines()
    out = []
    skipping = False
    removed_something = False

    for line in lines:
        # Check for start markers
        if MARKER_COMMENT_START in line or MARKER_RUNTIME_START in line:
            skipping = True
            removed_something = True
            continue # Don't write this line

        # Check for end markers
        if MARKER_COMMENT_END in line or MARKER_RUNTIME_END in line:
            skipping = False
            continue # Don't write this line

        # If not inside a block, keep the line
        if not skipping:
            out.append(line)
    
    # Clean up multiple empty lines resulting from removal
    cleaned_out = []
    prev_empty = False
    for line in out:
        is_empty = not line.strip()
        # Allow only one blank line
        if is_empty and prev_empty:
            continue
        cleaned_out.append(line)
        prev_empty = is_empty

    return '\n'.join(cleaned_out), removed_something

def insert_logo(content: str, logo: str, lang: str,
                colour_code: Optional[str]) -> str:
    """Insert commented logo + executable runtime bootstrap."""
    lines = content.splitlines()
    prefix = comment_prefix(lang)
    out = []

    # ---- 1. Commented logo (visible in editor) -----------------------
    out.append(f"{prefix}{MARKER_COMMENT_START}")
    if colour_code:
        out.append(f"{prefix}{colour_code}")
    logo_lines = logo.splitlines()
    for line in logo_lines:
        out.append(f"{prefix}{line}" if line.strip() else prefix)
    if colour_code:
        out.append(f"{prefix}{RESET}")
    out.append(f"{prefix}{MARKER_COMMENT_END}")
    out.append('')  # Blank line

    # ---- 2. Runtime bootstrap (executes on script start) -------------
    tmpl = RUNTIME_TEMPLATES.get(lang)
    if tmpl:
        # Prepare logo with newlines preserved
        logo_esc = '\n'.join(logo_lines)
        if lang == 'bash':
            logo_esc = logo_esc.replace("'", "'\\''")  # Escape for bash
        colour = colour_code or ''
        reset = RESET if colour_code else ''
        runtime = tmpl.format(logo=logo_esc, colour=colour, reset=reset)
        
        out.append(f"{prefix}{MARKER_RUNTIME_START}")
        for line in runtime.splitlines():
            out.append(line)
        out.append(f"{prefix}{MARKER_RUNTIME_END}")
        out.append('')  # Blank line

    # ---- 3. Original script (keep shebang on line 1) -----------------
    if lines and lines[0].startswith('#!'):
        return '\n'.join([lines[0]] + out + lines[1:])
    return '\n'.join(out + lines)

def colour_menu() -> None:
    print("\nAvailable colours:")
    for num, (code, name) in COLORS.items():
        sample = f"{code}███ SAMPLE{RESET}" if code else "███ Default"
        print(f"  [{num.rjust(2)}] {sample}  →  {name}")

# ----------------------------------------------------------------------
# Installation
# ----------------------------------------------------------------------
def install_self() -> None:
    """Install this script to ~/bin/logo (first run only)."""
    # Uses Path.home() / "bin" for better OS compatibility (e.g., macOS, custom Linux)
    bin_dir = Path.home() / "bin"
    bin_dir.mkdir(exist_ok=True, parents=True)

    self_path = Path(sys.argv[0]).resolve()
    target = bin_dir / "logo"

    if target.exists() and target.samefile(self_path):
        print(f"[!] Already running from installed location: {target}")
        return

    if target.exists():
        print(f"[!] Updating installation at {target}...")
    else:
        print(f"Installing to {target}...")
    
    try:
        shutil.copy(self_path, target)
        target.chmod(0o755)
        print("Installed successfully.")
    except Exception as e:
        print(f"[!] Installation failed: {e}")
        return

    # Advise on PATH
    print("\nAdd ~/bin to your PATH if not already (e.g., in ~/.bashrc):")
    print('export PATH="$HOME/bin:$PATH"')
    print("\nThen, source ~/.bashrc or restart terminal.")
    print("Usage: logo -i <script_file> OR logo -r <script_file>")

def create_backup(target: Path) -> None:
    backup = target.with_suffix(target.suffix + '.orig')
    backup.write_text(target.read_text(encoding='utf-8'), encoding='utf-8')
    print(f"Original backed up → {backup}")

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add or Remove coloured ASCII logo in scripts. Installs on first run if no arguments."
    )
    # Mutually exclusive group for -i (insert) or -r (remove)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-i', '--input', help='Target script file to ADD logo')
    group.add_argument('-r', '--remove', help='Target script file to REMOVE logo', metavar='FILE')
    
    parser.add_argument('--no-save-orig', action='store_true',
                        help='Do NOT create *.orig backup')
    
    args = parser.parse_args()

    # ---- Auto-install if no input file --------------------------------
    if not args.input and not args.remove:
        install_self()
        sys.exit(0)

    # ------------------------------------------------------------------
    # --- Removal Logic (-r) 🗑️ ----------------------------------------
    # ------------------------------------------------------------------
    if args.remove:
        target = Path(args.remove)
        if not target.exists():
            print(f"[!] File not found: {target}")
            sys.exit(1)
            
        if not args.no_save_orig:
            create_backup(target)
            
        content = target.read_text(encoding='utf-8')
        new_content, was_removed = remove_logo(content)
        
        if was_removed:
            target.write_text(new_content, encoding='utf-8')
            print(f"[✓] Logo removed successfully from {target}")
        else:
            print(f"[!] No logo markers found in {target}. Nothing changed.")
        sys.exit(0)

    # ------------------------------------------------------------------
    # --- Insertion Logic (-i) ✨ --------------------------------------
    # ------------------------------------------------------------------
    target = Path(args.input)
    if not target.exists():
        print(f"[!] File not found: {target}")
        sys.exit(1)

    # Load logos
    logos = load_ascii_logos(ASCII_FILE)
    if not logos:
        print("[!] No logos found.")
        sys.exit(1)

    # Choose final colour
    print("\nNow pick the **final** colour that will be written into the script:")
    colour_menu()
    while True:
        ch = input("\nSelect **final** colour [0-14, 0 = none]: ").strip()
        if ch in COLORS:
            final_code, final_name = COLORS[ch]
            final_code = None if ch == '0' else final_code
            print(f" → Final colour: {final_name}")
            break
        print("[!] Invalid – pick 0‑14.")

    # Choose logo
    print("\nAvailable logos (first line only):")
    for n in sorted(logos, key=int):
        first = logos[n].split('\n', 1)[0][:50]
        print(f"  [{n}] {first}...")
    while True:
        logo_num = input(f"\nPick logo number (1-{max(logos, key=int)}): ").strip()
        if logo_num in logos: break
        print("[!] Not a valid number.")
    chosen_logo = logos[logo_num]

    # Detect language
    lang = detect_script_type(target)
    print(f"\nDetected language: {lang.upper()}")

    # Check if logo already exists
    current_content = target.read_text(encoding='utf-8')
    if MARKER_COMMENT_START in current_content:
        print("\n[!] Warning: It looks like this file already has a logo.")
        c = input("    Continue and append new logo anyway? (y/N): ").lower()
        if c != 'y':
            print("Aborted.")
            sys.exit(0)

    # Backup
    if not args.no_save_orig:
        create_backup(target)

    # Insert logo
    new_content = insert_logo(current_content, chosen_logo, lang, final_code)
    target.write_text(new_content, encoding='utf-8')
    print(f"\nLogo #{logo_num} ({final_name}) inserted → {target}")

    # Final terminal preview
    print("\nFinal preview (as it will appear in a colour‑aware terminal):")
    preview = []
    if final_code:
        preview.append(final_code)
    preview.extend(chosen_logo.splitlines())
    if final_code:
        preview.append(RESET)
    print('\n'.join(preview))
    print()

if __name__ == '__main__':
    main()
