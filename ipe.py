#!/usr/bin/env python3
import sys
import os
import re
from urllib.parse import urlparse
import ipaddress

# Define the output file names
IP_FILENAME = "ex_ip.txt"
HTTP_FILENAME = "ex_http.txt"

def is_ip_address(domain):
    """
    Checks if a domain string is actually an IP address.
    """
    try:
        ipaddress.ip_address(domain)
        return True
    except ValueError:
        return False

def extract_data_from_sources(sources, output_dir):
    """
    Processes a list of file paths, extracts IPs and links.
    """
    print(f"Starting extraction...")
    print(f"Output directory set to: {output_dir}")

    unique_ips = set()
    unique_links = set()

    # Regex patterns
    IP_PATTERN = r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?::[0-9]+)?\b'
    HTTP_PATTERN = r'https?:\/\/[^\s]+'

    for full_path in sources:
        if not os.path.isfile(full_path):
            continue
            
        print(f"Processing: {os.path.basename(full_path)}")
        
        try:
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # 1. Extract raw IPs
            unique_ips.update(re.findall(IP_PATTERN, content))
            
            # 2. Extract Links and Filter IPs out of them
            raw_links = re.findall(HTTP_PATTERN, content)
            
            for link in raw_links:
                try:
                    parsed_url = urlparse(link)
                    hostname = parsed_url.hostname
                    
                    # Only add if it is NOT an IP address
                    if hostname and not is_ip_address(hostname):
                        unique_links.add(link)
                except Exception:
                    continue

        except Exception as e:
            print(f"Error reading {full_path}: {e}")
            
    # Construct full output paths
    ip_output_path = os.path.join(output_dir, IP_FILENAME)
    http_output_path = os.path.join(output_dir, HTTP_FILENAME)

    # Save IPs
    try:
        with open(ip_output_path, 'w') as f:
            for ip in sorted(unique_ips):
                f.write(ip + '\n')
    except PermissionError:
        print(f"Error: Permission denied writing to {ip_output_path}")
        return

    # Save Links
    try:
        with open(http_output_path, 'w') as f:
            for link in sorted(unique_links):
                f.write(link + '\n')
    except PermissionError:
        print(f"Error: Permission denied writing to {http_output_path}")
        return
            
    print("---")
    print("✅ Extraction complete!")
    print(f"IPs saved to:   {ip_output_path}")
    print(f"Links saved to: {http_output_path}")

def main():
    if len(sys.argv) < 2:
        print("Usage 1 (Folder):      ipe -i <folder_path>")
        print("Usage 2 (Single File): ipe <file_path>")
        sys.exit(1)

    source_files = []
    output_directory = ""

    # Check for the folder flag (-i)
    if sys.argv[1] == '-i':
        if len(sys.argv) != 3:
            print("Error: -i flag requires a folder path.")
            sys.exit(1)
            
        folder_path = sys.argv[2]
        if not os.path.isdir(folder_path):
            print(f"Error: Directory '{folder_path}' not found.")
            sys.exit(1)

        output_directory = folder_path

        for item_name in os.listdir(folder_path):
            full_path = os.path.join(folder_path, item_name)
            if os.path.isfile(full_path):
                source_files.append(full_path)
    
    # Check if input is a single file
    elif os.path.isfile(sys.argv[1]):
        file_path = os.path.abspath(sys.argv[1])
        source_files.append(file_path)
        output_directory = os.path.dirname(file_path)
        
    else:
        print(f"Error: Argument '{sys.argv[1]}' is not a valid flag (-i) or file.")
        sys.exit(1)
        
    if not source_files:
        print("Warning: No files found to process.")
        sys.exit(0)
        
    extract_data_from_sources(source_files, output_directory)

if __name__ == "__main__":
    main()
