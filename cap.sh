#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 -i <input_cap_file>"
    echo "  -i    Path to the input .cap file containing the handshake"
    exit 1
}

# Function to check and install dependencies
check_dependencies() {
    if ! command -v hcxpcapngtool &> /dev/null; then
        echo "[!] hcxtools is not installed."
        
        # Check if running as root
        if [ "$EUID" -ne 0 ]; then
            echo "Error: To auto-install dependencies, this script must be run with sudo."
            echo "Try: sudo $0 -i <file>"
            exit 1
        fi

        echo "[*] Attempting to install hcxtools..."
        
        # Update and install
        apt-get update
        apt-get install -y hcxtools

        # Verify installation succeeded
        if ! command -v hcxpcapngtool &> /dev/null; then
            echo "Error: Installation failed. Please install manually: sudo apt install hcxtools"
            exit 1
        else
            echo "[*] hcxtools installed successfully."
        fi
    fi
}

# Run the dependency check immediately
check_dependencies

# Parse command line arguments
INPUT_FILE=""

while getopts ":i:" opt; do
  case ${opt} in
    i)
      INPUT_FILE=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

# Check if -i argument was provided
if [ -z "$INPUT_FILE" ]; then
    echo "Error: Input file argument (-i) is required."
    usage
fi

# Check if the input file actually exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found!"
    exit 1
fi

# Define output filename
OUTPUT_FILE="${INPUT_FILE%.*}.hc22000"

echo "--------------------------------------------------"
echo "Converting '$INPUT_FILE' to Hashcat Mode 22000..."
echo "--------------------------------------------------"

# Run the conversion tool
hcxpcapngtool -o "$OUTPUT_FILE" "$INPUT_FILE"

# Check success
if [ $? -eq 0 ]; then
    echo "--------------------------------------------------"
    echo "Success! Output saved to: $OUTPUT_FILE"
    echo "You can now run hashcat: hashcat -m 22000 $OUTPUT_FILE wordlist.txt"
    echo "--------------------------------------------------"
else
    echo "Error during conversion. Please check if the .cap file contains a valid handshake."
fi
