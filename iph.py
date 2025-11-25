#!/usr/bin/env python3
import sys
import socket
import threading
import re
import ssl

PORTS = [80, 81, 443, 8000, 8080, 8081, 8443, 3000, 5000]

def check_port(ip, port, timeout=3):
    try:
        s = socket.socket()
        s.settimeout(timeout)
        s.connect((ip, port))
        s.close()
        return True
    except:
        return False

def get_banner(ip, port):
    try:
        if port in [443, 8443]:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            s = ctx.wrap_socket(socket.socket(), server_hostname=ip)
        else:
            s = socket.socket()
        s.settimeout(6)
        s.connect((ip, port))

        s.send(f"GET / HTTP/1.1\r\nHost: {ip}\r\nUser-Agent: Mozilla/5.0\r\n\r\n".encode())
        resp = s.recv(8192)
        s.close()

        text = resp.decode(errors='ignore')

        status = re.search(r'HTTP/1\.[01] (\d{3})', text)
        status = status.group(1) if status else "???"

        server = re.search(r'Server: (.*?)\r\n', text, re.I)
        server = server.group(1).strip() if server else "Unknown"

        title = re.search(r'<title>(.*?)</title>', text, re.I | re.S)
        title = re.sub(r'\s+', ' ', title.group(1).strip())[:100] if title else "No title"

        proto = "https" if port in [443, 8443] else "http"
        return f"{ip} → {proto}://{ip}:{port}/  |  {status}  |  {server}  |  {title}"
    except:
        proto = "https" if port in [443, 8443] else "http"
        return f"{ip} → {proto}://{ip}:{port}/  |  OPEN (no banner)"

def scan_ip(ip):
    ip = ip.strip()
    results = []
    found = False

    for port in PORTS:
        if check_port(ip, port):
            found = True
            banner = get_banner(ip, port)
            results.append(banner)

    if not found:
        results.append(f"{ip} → No web ports open (80, 443, 8080, etc.)")

    return results

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 ipscan.py 192.168.1.165          # single IP → show in terminal")
        print("  python3 ipscan.py -i ips.txt              # from file → save to ip_to_http.txt")
        sys.exit(1)

    arg = sys.argv[1]

    # Case 1: Single IP without flag
    if arg != "-i" and len(sys.argv) == 2:
        ip = arg
        print(f"[+] Scanning: {ip}\n")
        results = scan_ip(ip)
        for line in results:
            print(line)

    # Case 2: File with -i
    elif arg == "-i" and len(sys.argv) == 3:
        filename = sys.argv[2]
        try:
            with open(filename) as f:
                ips = [line.strip() for line in f if line.strip()]
        except:
            print(f"[!] Cannot open file: {filename}")
            sys.exit(1)

        print(f"[+] Loading {len(ips)} IPs from {filename}")
        print("[+] Scanning... (this may take a while)\n")

        all_results = []
        threads = []

        def worker(ip):
            for line in scan_ip(ip):
                all_results.append(line)

        for ip in ips:
            t = threading.Thread(target=worker, args=(ip,))
            t.start()
            threads.append(t)

        for t in threads:
            t.join()

        # Save to file
        with open("ip_to_http.txt", "w", encoding="utf-8") as f:
            for line in all_results:
                f.write(line + "\n")
                print(line)  # also show in terminal

        print(f"\n[+] Done! All results saved to → ip_to_http.txt")

    else:
        print("Invalid usage!")
        print("Use: ipscan.py <IP>    or    ipscan.py -i file.txt")
        sys.exit(1)

if __name__ == "__main__":
    main()
