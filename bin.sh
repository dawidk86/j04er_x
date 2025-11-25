#!/bin/bash

# install-tool.sh - Install any script/folder (Bash or Python) as a system command
# Usage: install-tool.sh -i <folder|script.sh|script.py>
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    cat <<EOF
Usage: $(basename "$0") -i <folder|script.sh|script.py>
  -i <path> Path to a script file (.sh or .py) OR a folder containing scripts
  -h        Show this help

Examples:
  $(basename "$0") -i ~/mytools/scan.sh
  $(basename "$0") -i ~/mytools/webscan.py
  $(basename "$0") -i ~/mytools/scan_project/

Supported:
  • Single .sh or .py files
  • Project folders with main.sh, main.py, run.py, start.sh, etc.
  • Python scripts with or without shebang
EOF
    exit 1
}

# Parse args
input_path=""
while (( $# )); do
    case "$1" in
        -i) input_path="$2"; shift 2 ;;
        -h|--help) show_help ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help ;;
    esac
done

[[ -z "$input_path" ]] && { echo -e "${RED}Error: -i is required${NC}"; show_help; }

# Resolve full path
input_path="$(realpath "$input_path")"
if [[ ! -e "$input_path" ]]; then
    echo -e "${RED}Error: Path not found: $input_path${NC}"
    exit 1
fi

# Ask for tool name
while true; do
    echo -e "${YELLOW}Enter the command name (e.g. scan, webscan, backup):${NC}"
    read -rp " > " tool_name
    tool_name="${tool_name// /_}" # replace spaces with _
    if [[ -z "$tool_name" ]]; then
        echo -e "${RED}Name cannot be empty!${NC}"
    elif [[ "$tool_name" =~ ^[0-9] ]]; then
        echo -e "${RED}Name cannot start with a number!${NC}"
    elif [[ "$tool_name" =~ [^a-zA-Z0-9_-] ]]; then
        echo -e "${RED}Only letters, numbers, _, - allowed!${NC}"
    elif command -v "$tool_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: '$tool_name' already exists in PATH!${NC}"
        read -rp "Overwrite? (y/N): " overwrite
        [[ "$overwrite" =~ ^[Yy]$ ]] && break
    else
        break
    fi
done

echo -e "${GREEN}Installing as command: $tool_name${NC}"

# ————————————————————————————————————————————————————————
# CASE 1: Single script file (.sh or .py)
# ————————————————————————————————————————————————————————
if [[ -f "$input_path" ]]; then
    filename="$(basename "$input_path")"
    ext="${filename##*.}"
    target="/usr/local/bin/$tool_name"

    if [[ "$ext" == "sh" ]]; then
        # Bash script
        sudo cp "$input_path" "$target"
        sudo chmod +x "$target"
        echo -e "${GREEN}Installed Bash script → $target${NC}"

    elif [[ "$ext" == "py" ]]; then
        # Python script
        sudo cp "$input_path" "$target.py"  # Keep .py for clarity

        # Detect if script has shebang
        if head -1 "$input_path" | grep -q "^#!/usr/bin/env python"; then
            shebang="#!/usr/bin/env python3"
        elif head -1 "$input_path" | grep -q "^#!/usr/bin/python"; then
            shebang="#!/usr/bin/python3"
        else
            shebang="#!/usr/bin/env python3"
        fi

        # Create executable wrapper
        sudo tee "$target" > /dev/null <<EOF
#!/bin/bash
exec $shebang "$target.py" "\$@"
EOF
        sudo chmod +x "$target"
        sudo chmod +x "$target.py"
        echo -e "${GREEN}Installed Python script → $target${NC}"
        echo -e "   Script: $target.py"

    else
        echo -e "${RED}Error: Unsupported file type. Use .sh or .py${NC}"
        exit 1
    fi

    exit 0
fi

# ————————————————————————————————————————————————————————
# CASE 2: Folder (multi-file project)
# ————————————————————————————————————————————————————————
if [[ -d "$input_path" ]]; then
    opt_dir="/opt/$tool_name"
    wrapper="/usr/local/bin/$tool_name"

    # Detect main script: prioritize .py if both exist
    main_script=""
    for candidate in "main.py" "$tool_name.py" "run.py" "start.py" "bin/main.py" "bin/run.py"; do
        if [[ -f "$input_path/$candidate" ]]; then
            main_script="$candidate"
            break
        fi
    done

    # Fallback to .sh if no .py found
    if [[ -z "$main_script" ]]; then
        for candidate in "main.sh" "$tool_name.sh" "start.sh" "run.sh" "bin/main.sh" "bin/run.sh"; do
            if [[ -f "$input_path/$candidate" ]]; then
                main_script="$candidate"
                break
            fi
        done
    fi

    if [[ -z "$main_script" ]]; then
        echo -e "${RED}Error: No main script found in folder!${NC}"
        echo "Expected one of:"
        echo "  main.py, $tool_name.py, run.py, start.py"
        echo "  main.sh, $tool_name.sh, start.sh, run.sh"
        echo "  bin/*.py or bin/*.sh"
        exit 1
    fi

    # Determine script type
    script_type=""
    if [[ "$main_script" =~ \.py$ ]]; then
        script_type="python"
    elif [[ "$main_script" =~ \.sh$ ]]; then
        script_type="bash"
    else
        echo -e "${RED}Unknown script type: $main_script${NC}"
        exit 1
    fi

    # Install to /opt/
    sudo mkdir -p "$opt_dir"
    sudo cp -r "$input_path"/* "$opt_dir/" 2>/dev/null || true
    sudo cp -r "$input_path"/.* "$opt_dir/" 2>/dev/null || true  # hidden files

    # Optional: detect and activate virtual environment
    venv_path=""
    if [[ -f "$opt_dir/venv/bin/activate" ]]; then
        venv_path="$opt_dir/venv"
    elif [[ -f "$opt_dir/.venv/bin/activate" ]]; then
        venv_path="$opt_dir/.venv"
    fi

    # Create wrapper
    if [[ "$script_type" == "python" ]]; then
        # Python wrapper with optional venv
        if [[ -n "$venv_path" ]]; then
            echo -e "${BLUE}Virtual environment detected: $venv_path${NC}"
            sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
source "$venv_path/bin/activate"
exec python "$opt_dir/$main_script" "\$@"
EOF
        else
            sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
exec python3 "$opt_dir/$main_script" "\$@"
EOF
        fi
    else
        # Bash wrapper
        sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
exec "$opt_dir/$main_script" "\$@"
EOF
    fi

    sudo chmod +x "$wrapper"
    echo -e "${GREEN}Multi-file project installed!${NC}"
    echo " Files → $opt_dir/"
    echo " Main  → $main_script"
    [[ -n "$venv_path" ]] && echo " Venv  → $venv_path"
    echo " Command → $tool_name"
    exit 0
fi

# ————————————————————————————————————————————————————————
echo -e "${RED}Error: Input must be a .sh/.py file or a directory${NC}"
exit 1