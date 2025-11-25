#!/usr/bin/env python3
"""
IP Extractor Tool – extracts **ALL** IPv4 addresses (public, private, loopback) from Nmap .txt scan results.
Features
--------
- Extracts *every* valid IPv4 address
- No filtering (private, loopback, reserved all included)
- Robust regex + ipaddress validation
- Sorted output (natural IP order)
- Creates <input>_extracted.txt
"""

import argparse
import os
import re
import sys
from ipaddress import ip_address
from typing import List, Set

# --------------------------------------------------------------------------- #
# IP EXTRACTION (ALL IPs)
# --------------------------------------------------------------------------- #
IPV4_PATTERN = re.compile(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b')

def _octets_valid(ip: str) -> bool:
    """Check that each octet is 0–255 (extra safety before ip_address())."""
    return all(0 <= int(o) <= 255 for o in ip.split('.'))

def extract_all_ips(path: str) -> List[str]:
    """
    Extract **all** valid IPv4 addresses from the file.
    Returns sorted list of IP strings (natural order).
    """
    found: Set[str] = set()

    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            for candidate in IPV4_PATTERN.findall(line):
                if not _octets_valid(candidate):
                    continue
                # This will raise ValueError if it's not a real IP → we skip those
                try:
                    addr = ip_address(candidate)
                    if addr.version == 4:
                        found.add(str(addr))
                except ValueError:
                    continue

    return sorted(found, key=lambda ip: tuple(int(part) for part in ip.split('.')))

# --------------------------------------------------------------------------- #
# ARGUMENT PARSING
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract ALL IPv4 addresses (public, private, loopback) from Nmap .txt scan results"
    )
    parser.add_argument(
        '-i', '--input',
        required=True,
        help='Path to the Nmap .txt file'
    )
    return parser

# --------------------------------------------------------------------------- #
# MAIN LOGIC
# --------------------------------------------------------------------------- #
def main() -> None:
    # Removed print_logo() – script now works without it
    args = build_parser().parse_args()

    in_path = os.path.abspath(args.input.strip())

    if not os.path.isfile(in_path):
        print(f"[!] File not found: {in_path}")
        sys.exit(1)

    if not in_path.lower().endswith('.txt'):
        print("[!] Please provide a .txt file (Nmap output).")
        sys.exit(1)

    print(f"[+] Scanning: {in_path}")

    ips = extract_all_ips(in_path)

    # Output file matches the name in the docstring: <input>_extracted.txt
    out_path = os.path.splitext(in_path)[0] + "_extracted.txt"

    if not ips:
        print("[!] No IPv4 addresses found.")
        open(out_path, 'w', encoding='utf-8').close()
    else:
        with open(out_path, 'w', encoding='utf-8') as f:
            for ip in ips:
                f.write(ip + '\n')
        print(f"[+] Extracted {len(ips)} unique IP(s) → {out_path}")

    print("\nDone! Happy hacking!\n")

if __name__ == '__main__':
    main()