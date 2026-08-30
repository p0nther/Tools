#!/bin/bash

# Enhanced Recon Script
# Usage: ./recon.sh <domain> [github-org-or-repo-url]
# Required tools: whatweb, nmap, subfinder, puredns, httpx, naabu, subjack, trufflehog, nuclei, waybackurls

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║           Enhanced Recon Script v2.0                      ║
║  Subdomain Discovery | Port Scanning | Takeover Detection ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [ -z "$1" ]; then
    echo -e "${RED}[!] Usage: $0 <domain> [github-org-or-repo-url]${NC}"
    echo -e "${YELLOW}[*] Example (Org):  $0 example.com example-org${NC}"
    echo -e "${YELLOW}[*] Example (Repo): $0 example.com https://github.com/org/repo${NC}"
    exit 1
fi

DOMAIN=$1
GITHUB_TARGET=$2
TARGET_DIR="${DOMAIN}"

# Create organized directory structure
mkdir -p "$TARGET_DIR"/{subs,dns,web,ports,takeover,secrets,logs}

# File paths organized by category
SUBS_RAW="$TARGET_DIR/subs/subdomains_raw.txt"
SUBS_VALIDATED="$TARGET_DIR/dns/subdomains_validated.txt"
RESOLVERS="$TARGET_DIR/dns/resolvers.txt"
LIVE_FILE="$TARGET_DIR/web/live_subdomains.txt"
LIVE_HOSTS="$TARGET_DIR/web/live_hosts.txt"
HTTPX_FULL="$TARGET_DIR/web/httpx_full_output.txt"
LIVE_URLS="$TARGET_DIR/web/live_urls.txt"
ALL_URLS="$TARGET_DIR/web/wayback_urls.txt"
JS_FILES="$TARGET_DIR/web/js_files.txt"
MANTRA_OUT="$TARGET_DIR/web/mantra_results.txt"
PORTS_FILE="$TARGET_DIR/ports/all_ports.txt"
NMAP_OUT="$TARGET_DIR/ports/nmap_scan.txt"
TAKEOVER_FILE="$TARGET_DIR/takeover/subjack_results.txt"
NUCLEI_OUT="$TARGET_DIR/web/nuclei_results.txt"
TRUFFLEHOG_OUT="$TARGET_DIR/secrets/github_secrets.json"
INFO_FILE="$TARGET_DIR/logs/all_info.txt"
WHATWEB_OUT="$TARGET_DIR/logs/whatweb.txt"

# Counters — initialized so the final summary never prints blank
SUBFINDER_COUNT=0
VALIDATED_COUNT=0
LIVE_COUNT=0
JS_COUNT=0
URL_COUNT=0
PORT_COUNT=0
TAKEOVER_COUNT=0
SECRET_COUNT=0
NUCLEI_COUNT=0

# Function to add blank lines
blank_lines() {
    printf "\n%.0s" {1..3} | tee -a "$INFO_FILE" > /dev/null
}

# Function to print status
print_status() {
    echo -e "${GREEN}[+] $1${NC}" | tee -a "$INFO_FILE"
}

print_error() {
    echo -e "${RED}[!] $1${NC}" | tee -a "$INFO_FILE"
}

print_info() {
    echo -e "${YELLOW}[*] $1${NC}" | tee -a "$INFO_FILE"
}

# Check if required tools are installed
check_tools() {
    local tools=("subfinder" "puredns" "httpx" "naabu" "subjack" "nuclei")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing tools: ${missing[*]}"
        print_info "Install with: go install -v github.com/projectdiscovery/<tool>/cmd/<tool>@latest"
        return 1
    fi

    print_status "All required tools are installed!"
    return 0
}

# ---------- Tool Check ----------
print_status "Checking required tools..."
check_tools || exit 1

# ---------- Some Tech Info ----------
blank_lines
print_status "Gathering tech info with whatweb..."
echo "---------- Tech Info (whatweb) ----------" | tee -a "$INFO_FILE"

whatweb "https://$DOMAIN" -v >> "$WHATWEB_OUT" 2>/dev/null
cat "$WHATWEB_OUT" >> "$INFO_FILE"

# ---------- Nmap Scan ----------
blank_lines
print_status "Running Nmap scan on main domain..."
echo "---------- Nmap Scan ----------" | tee -a "$INFO_FILE"
nmap -A --script="default,http-methods" -oN "$NMAP_OUT" "$DOMAIN" >> "$INFO_FILE" 2>/dev/null

# ---------- STEP 1: Subdomain Enumeration with Subfinder ----------
blank_lines
print_status "Step 1: Enumerating subdomains with subfinder..."
echo "---------- Subdomain Enumeration (subfinder) ----------" | tee -a "$INFO_FILE"

subfinder -d "$DOMAIN" -silent -o "$SUBS_RAW" 2>/dev/null
echo "$DOMAIN" >> "$SUBS_RAW"
sort -u "$SUBS_RAW" -o "$SUBS_RAW"

SUBFINDER_COUNT=$(wc -l < "$SUBS_RAW" 2>/dev/null || echo "0")
print_status "Found $SUBFINDER_COUNT subdomains with subfinder"

# ---------- STEP 2: DNS Validation with PureDNS ----------
blank_lines
print_status "Step 2: Validating subdomains with puredns..."
echo "---------- DNS Validation (puredns) ----------" | tee -a "$INFO_FILE"

if [ -f "$SUBS_RAW" ] && [ -s "$SUBS_RAW" ]; then
    # PureDNS requires a resolvers list - using public DNSs
    echo "8.8.8.8" > "$RESOLVERS"
    echo "8.8.4.4" >> "$RESOLVERS"
    echo "1.1.1.1" >> "$RESOLVERS"
    echo "1.0.0.1" >> "$RESOLVERS"

    puredns resolve "$SUBS_RAW" -r "$RESOLVERS" -w "$SUBS_VALIDATED" 2>/dev/null

    VALIDATED_COUNT=$(wc -l < "$SUBS_VALIDATED" 2>/dev/null || echo "0")
    print_status "Validated $VALIDATED_COUNT subdomains with puredns"
else
    print_error "No subdomains found by subfinder"
    touch "$SUBS_VALIDATED"
fi

# ---------- STEP 3: Live Subdomain Detection with httpX ----------
blank_lines
print_status "Step 3: Checking live subdomains with httpx..."
echo "---------- Live Subdomains (httpx) ----------" | tee -a "$INFO_FILE"

if [ -f "$SUBS_VALIDATED" ] && [ -s "$SUBS_VALIDATED" ]; then
    httpx -l "$SUBS_VALIDATED" \
        -ports 80,443 \
        -title -status-code -tech-detect -follow-redirects \
        -silent -o "$LIVE_FILE" 2>/dev/null

    LIVE_COUNT=$(wc -l < "$LIVE_FILE" 2>/dev/null || echo "0")
    print_status "Found $LIVE_COUNT live subdomains"

    # Extract just the URLs for port scanning and nuclei
    cat "$LIVE_FILE" | awk '{print $1}' | sort -u > "$LIVE_URLS"
    cat "$LIVE_FILE" | awk '{print $1}' | sed 's|https://||' | sed 's|:.*||' | sort -u > "$LIVE_HOSTS"
else
    print_error "No validated subdomains to check"
    touch "$LIVE_FILE" "$LIVE_URLS" "$LIVE_HOSTS"
fi

# ---------- STEP 4: Extract JavaScript Files from Wayback Machine ----------
blank_lines
print_status "Step 4: Gathering URLs from Wayback Machine..."
echo "---------- JavaScript Discovery (waybackurls) ----------" | tee -a "$INFO_FILE"

if [ -f "$LIVE_HOSTS" ] && [ -s "$LIVE_HOSTS" ]; then

    if command -v waybackurls &> /dev/null; then

        cat "$LIVE_HOSTS" | waybackurls > "$ALL_URLS" 2>/dev/null

        URL_COUNT=$(wc -l < "$ALL_URLS" 2>/dev/null || echo "0")
        print_status "Collected $URL_COUNT historical URLs"

        grep -E "\.js(\?|$)" "$ALL_URLS" | sort -u > "$JS_FILES"

        JS_COUNT=$(wc -l < "$JS_FILES" 2>/dev/null || echo "0")
        print_status "Found $JS_COUNT JavaScript files"

        if [ "$JS_COUNT" -gt 0 ]; then
            print_info "JavaScript files saved to: $JS_FILES"

            if command -v mantra &> /dev/null; then
                print_info "Running mantra against collected JS files..."
                cat "$JS_FILES" | mantra | tee "$MANTRA_OUT"
            else
                print_error "mantra not installed — skipping"
            fi
        fi

    else
        print_error "waybackurls not installed"
        print_info "Install with:"
        print_info "go install github.com/tomnomnom/waybackurls@latest"
        touch "$ALL_URLS" "$JS_FILES"
    fi

else
    print_error "No live hosts found for Wayback collection"
    touch "$ALL_URLS" "$JS_FILES"
fi

# ---------- STEP 5: Port Scanning with Naabu ----------
blank_lines
print_status "Step 5: Scanning all ports with naabu..."
echo "---------- Port Scanning (naabu) ----------" | tee -a "$INFO_FILE"

if [ -f "$LIVE_HOSTS" ] && [ -s "$LIVE_HOSTS" ]; then
    naabu -list "$LIVE_HOSTS" \
        -p - \
        -silent \
        -o "$PORTS_FILE" 2>/dev/null

    PORT_COUNT=$(wc -l < "$PORTS_FILE" 2>/dev/null || echo "0")
    print_status "Found $PORT_COUNT open ports across all subdomains"

    # Show summary
    if [ -f "$PORTS_FILE" ] && [ -s "$PORTS_FILE" ]; then
        echo "" | tee -a "$INFO_FILE"
        print_info "Port scan summary:"
        cat "$PORTS_FILE" | tee -a "$INFO_FILE"
    fi
else
    print_error "No live hosts to scan"
    touch "$PORTS_FILE"
fi

# ---------- STEP 6: Subdomain Takeover Detection with Subjack ----------
blank_lines
print_status "Step 6: Checking for subdomain takeover with subjack..."
echo "---------- Subdomain Takeover (subjack) ----------" | tee -a "$INFO_FILE"

if [ -f "$SUBS_VALIDATED" ] && [ -s "$SUBS_VALIDATED" ]; then
    subjack -w "$SUBS_VALIDATED" \
        -t 100 \
        -timeout 30 \
        -ssl \
        -o "$TAKEOVER_FILE" 2>/dev/null

    if [ -f "$TAKEOVER_FILE" ] && [ -s "$TAKEOVER_FILE" ]; then
        TAKEOVER_COUNT=$(wc -l < "$TAKEOVER_FILE")
        print_error "⚠️  FOUND $TAKEOVER_COUNT POTENTIAL SUBDOMAIN TAKEOVERS!"
        cat "$TAKEOVER_FILE" | tee -a "$INFO_FILE"
    else
        print_status "No subdomain takeovers detected"
    fi
else
    print_error "No subdomains to check for takeover"
fi

# ---------- STEP 7: GitHub Secret Scanning with TruffleHog ----------
blank_lines
if [ -n "$GITHUB_TARGET" ]; then
    echo "---------- GitHub Secrets (trufflehog) ----------" | tee -a "$INFO_FILE"

    if command -v trufflehog &> /dev/null; then
        if [[ "$GITHUB_TARGET" == http* ]]; then
            print_status "Step 7: Scanning GitHub repository '$GITHUB_TARGET' with trufflehog..."
            trufflehog github --repo="$GITHUB_TARGET" --json > "$TRUFFLEHOG_OUT" 2>/dev/null
        else
            print_status "Step 7: Scanning GitHub organization '$GITHUB_TARGET' with trufflehog..."
            trufflehog github --org="$GITHUB_TARGET" --json > "$TRUFFLEHOG_OUT" 2>/dev/null
        fi

        if [ -f "$TRUFFLEHOG_OUT" ] && [ -s "$TRUFFLEHOG_OUT" ]; then
            SECRET_COUNT=$(grep -c "Raw" "$TRUFFLEHOG_OUT" 2>/dev/null || echo "0")
            if [ "$SECRET_COUNT" -gt 0 ]; then
                print_error "⚠️  FOUND $SECRET_COUNT POTENTIAL SECRETS IN GITHUB!"
                print_info "Check $TRUFFLEHOG_OUT for details"
            else
                print_status "No secrets found in GitHub"
            fi
        else
            print_status "No secrets found in GitHub"
        fi
    else
        print_error "TruffleHog not installed. Install with: pip install trufflehog"
        print_info "Or: brew install trufflesecurity/trufflehog/trufflehog"
    fi
else
    print_info "Step 7: Skipping GitHub scan (no organization or repo URL specified)"
    print_info "To scan GitHub: $0 $DOMAIN <github-org-or-repo-url>"
fi

# ---------- STEP 8: Vulnerability Scanning with Nuclei ----------
blank_lines
print_status "Step 8: Scanning for vulnerabilities with nuclei..."
echo "---------- Vulnerability Scan (nuclei) ----------" | tee -a "$INFO_FILE"

if [ -f "$LIVE_URLS" ] && [ -s "$LIVE_URLS" ]; then
    nuclei -l "$LIVE_URLS" -as -silent \
        -o "$NUCLEI_OUT" 2>/dev/null

    NUCLEI_COUNT=$(wc -l < "$NUCLEI_OUT" 2>/dev/null || echo "0")
    if [ "$NUCLEI_COUNT" -gt 0 ]; then
        print_error "⚠️  FOUND $NUCLEI_COUNT POTENTIAL VULNERABILITIES!"
        print_info "Check $NUCLEI_OUT for details"
    else
        print_status "No vulnerabilities found by nuclei"
    fi
else
    print_error "No live URLs to scan with nuclei"
    touch "$NUCLEI_OUT"
fi

# ---------- Summary ----------
blank_lines
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}       Recon Finished Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
print_status "Results Summary:"
echo "  • Subdomains found: $SUBFINDER_COUNT"
echo "  • Validated subdomains: $VALIDATED_COUNT"
echo "  • Live subdomains: $LIVE_COUNT"
echo "  • JS files discovered: $JS_COUNT"
echo "  • Open ports discovered: $PORT_COUNT"
echo "  • Nuclei vulnerabilities: $NUCLEI_COUNT"
echo ""
print_status "Output directory: $(pwd)/$TARGET_DIR"
echo ""
print_info "Directory Structure:"
echo "  $TARGET_DIR/"
echo "  ├─ subs/          → Raw subdomain enumeration"
echo "  ├─ dns/           → DNS validated subdomains"
echo "  ├─ web/           → Live web hosts, JS files & httpx/nuclei results"
echo "  ├─ ports/         → Port scan results & nmap"
echo "  ├─ takeover/      → Subdomain takeover findings"
echo "  ├─ secrets/       → GitHub secrets scan"
echo "  └─ logs/          → Complete logs & tech info"
echo ""
print_info "Quick Access:"
echo "  • Live subdomains:    cat $TARGET_DIR/web/live_subdomains.txt"
echo "  • JS files:           cat $TARGET_DIR/web/js_files.txt"
echo "  • Open ports:         cat $TARGET_DIR/ports/all_ports.txt"
echo "  • Takeover results:   cat $TARGET_DIR/takeover/subjack_results.txt"
echo "  • Nuclei results:     cat $TARGET_DIR/web/nuclei_results.txt"
echo "  • All logs:           cat $TARGET_DIR/logs/all_info.txt"
echo ""
print_info "Next Steps:"
echo "  1. Work on subdomains one by one"
echo "  2. Focus on one function until you know everything about it"
echo "  3. Take notes (write all scenario for this function try anything in it)"
echo ""
print_status "Happy Hacking! 🎯"
