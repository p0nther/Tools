#!/bin/bash

# Usage: ./recon.sh website.com
# Required tools: whatweb, nmap, subfinder, httpx

if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN=$1
OUTPUT_DIR="$DOMAIN"

mkdir -p "$OUTPUT_DIR"

INFO_FILE="$OUTPUT_DIR/all_info.txt"
SUBS_FILE="$OUTPUT_DIR/subdomains.txt"
LIVE_FILE="$OUTPUT_DIR/live_sub.txt"
NMAP_OUT="$OUTPUT_DIR/nmap_scan.txt"
HTTPX_INPUT="$OUTPUT_DIR/subs_for_httpx.txt"

# Function to add blank lines
blank_lines() {
    printf "\n%.0s" {1..3} | tee -a "$INFO_FILE" > /dev/null
}

# ---------- Some Tech Info ----------
blank_lines
echo "---------- Some Tech Info \"whatweb\" ----------" | tee -a "$INFO_FILE"
whatweb http://$DOMAIN -v >> "$INFO_FILE" 2>/dev/null
whatweb https://$DOMAIN -v >> "$INFO_FILE" 2>/dev/null

# ---------- Nmap Scan ----------
blank_lines
echo "---------- Nmap Scan  \"-A --script=default,http-methods\"----------" | tee -a "$INFO_FILE"
nmap -A  --script="default,http-methods"  -oN "$NMAP_OUT" "$DOMAIN" >> "$INFO_FILE" 2>/dev/null

# ---------- Subdomain Enumeration ----------
blank_lines
echo "---------- Subdomain Enumeration \"subfinder\"----------" | tee -a "$INFO_FILE"

# Adjust TLD for subfinder if needed
SUBFINDER_DOMAIN="$DOMAIN"
if [[ "$DOMAIN" == *.thm ]]; then
    SUBFINDER_DOMAIN="${DOMAIN%.*}.com"
    echo "[!] Subfinder domain changed: $DOMAIN -> $SUBFINDER_DOMAIN" | tee -a "$INFO_FILE"
fi

subfinder -d "$SUBFINDER_DOMAIN" -o "$SUBS_FILE" >> "$INFO_FILE" 2>/dev/null

# Restore original TLD for httpx
ORIGINAL_TLD="${DOMAIN##*.}"
if [[ "$ORIGINAL_TLD" != "com" ]]; then
    sed "s/\.com$/.$ORIGINAL_TLD/" "$SUBS_FILE" > "$HTTPX_INPUT"
else
    cp "$SUBS_FILE" "$HTTPX_INPUT"
fi

# ---------- Live Subdomains ----------
blank_lines
echo "---------- Live Subdomains \"-ports(mostPop) -titel -status-code -tech-detect -follow-redirects\"----------" | tee -a "$INFO_FILE"
httpx -l "$HTTPX_INPUT" \
    -ports 80,443,8080,8443,8000,8888,3000,5000,7001,9443,9080,8090,8181,8500,9000,9200,5601,5984,5001,10000 \
    -title -status-code -tech-detect -follow-redirects -o "$LIVE_FILE" >> "$INFO_FILE" 2>/dev/null 

#cat "$LIVE_FILE" >> "$INFO_FILE"

blank_lines
echo "========= Recon Finished ========="
echo"1.work on subdomains one by one | 2.focus on one function until know all thing about it | 3.take notes for it  (credintial, interested page /admin , api)" | tee -a "$INFO_FILE"
echo "Results saved in: `pwd`/$OUTPUT_DIR"

