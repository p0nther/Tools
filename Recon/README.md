# 🎯 Enhanced Recon Script

A powerful automated reconnaissance script for security researchers and bug bounty hunters. This script streamlines the subdomain discovery, validation, and vulnerability detection process.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/bash-5.0%2B-green.svg)

## ✨ Features

- 🔍 **Subdomain Enumeration** - Discover subdomains using Subfinder
- ✅ **DNS Validation** - Validate discovered subdomains with PureDNS
- 🌐 **Live Host Detection** - Identify active web servers with httpX
- 🔓 **Port Scanning** - Comprehensive port scanning with Naabu
- ⚠️ **Subdomain Takeover Detection** - Find vulnerable subdomains with Subjack
- 🔐 **Secret Scanning** - Scan GitHub repositories for exposed secrets with TruffleHog
- 📊 **Tech Stack Detection** - Identify technologies with WhatWeb
- 🗺️ **Nmap Integration** - Detailed service detection and enumeration

## 📋 Prerequisites

### Required Tools

Install the following tools before running the script:

```bash
# Go-based tools (install via go install)
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/d3mondev/puredns/v2@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install -v github.com/haccer/subjack@latest

# TruffleHog (Python or Go)
pip install trufflehog
# OR
brew install trufflesecurity/trufflehog/trufflehog

# System tools
sudo apt install nmap whatweb  # Debian/Ubuntu
# OR
brew install nmap whatweb      # macOS
```

### System Requirements

- **OS**: Linux or macOS
- **Shell**: Bash 5.0+
- **Go**: 1.19+ (for installing Go-based tools)
- **Python**: 3.7+ (if using pip for TruffleHog)

## 🚀 Usage

### Basic Usage

```bash
chmod +x recon.sh
./recon.sh <domain>
```

**Example:**
```bash
./recon.sh example.com
```

### With GitHub Organization Scanning

```bash
./recon.sh <domain> <github-org>
```

**Example:**
```bash
./recon.sh example.com example-org
```

## 📁 Output Structure

The script creates an organized directory structure for all results:

```
example.com/
├── subs/          → Raw subdomain enumeration
│   └── subdomains_raw.txt
├── dns/           → DNS validated subdomains
│   ├── subdomains_validated.txt
│   └── resolvers.txt
├── web/           → Live web hosts & httpx results
│   ├── live_subdomains.txt
│   ├── live_hosts.txt
│   └── httpx_full_output.txt
├── ports/         → Port scan results & nmap
│   ├── all_ports.txt
│   └── nmap_scan.txt
├── takeover/      → Subdomain takeover findings
│   └── subjack_results.txt
├── secrets/       → GitHub secrets scan
│   └── github_secrets.json
└── logs/          → Complete logs & tech info
    ├── all_info.txt
    └── whatweb.txt
```

## 🔄 Workflow

1. **Tech Stack Detection** - Identifies technologies using WhatWeb
2. **Nmap Scan** - Performs detailed service detection on main domain
3. **Subdomain Discovery** - Enumerates subdomains with Subfinder
4. **DNS Validation** - Validates discovered subdomains with PureDNS
5. **Live Detection** - Checks for active web servers with httpX
6. **Port Scanning** - Scans all ports on live hosts with Naabu
7. **Takeover Detection** - Identifies potential subdomain takeovers with Subjack
8. **Secret Scanning** - Scans GitHub organization for exposed secrets (optional)

## 📊 Example Output

```
╔═══════════════════════════════════════════════════════════╗
║           Enhanced Recon Script v2.0                      ║
║  Subdomain Discovery | Port Scanning | Takeover Detection ║
╚═══════════════════════════════════════════════════════════╝

[+] Checking required tools...
[+] All required tools are installed!
[+] Gathering tech info with whatweb...
[+] Running Nmap scan on main domain...
[+] Step 1: Enumerating subdomains with subfinder...
[+] Found 47 subdomains with subfinder
[+] Step 2: Validating subdomains with puredns...
[+] Validated 42 subdomains with puredns
[+] Step 3: Checking live subdomains with httpx...
[+] Found 38 live subdomains
[+] Step 4: Scanning all ports with naabu...
[+] Found 156 open ports across all subdomains
[+] Step 5: Checking for subdomain takeover with subjack...
[+] No subdomain takeovers detected
[+] Step 6: Scanning GitHub organization 'example-org' with trufflehog...
[+] No secrets found in GitHub

========================================
       Recon Finished Successfully!
========================================
```

## ⚙️ Configuration

### Custom DNS Resolvers

The script uses public DNS resolvers by default (Google DNS, Cloudflare DNS). You can modify the resolvers in the script or provide your own `resolvers.txt` file.

### Port Scanning

By default, Naabu scans all ports (`-p -`). You can modify this in the script to scan specific ports:

```bash
naabu -list "$LIVE_HOSTS" -p 80,443,8080,8443 -silent -o "$PORTS_FILE"
```

## 🛡️ Security & Ethics

⚠️ **Important**: This tool is intended for authorized security testing only.

- Only scan domains you own or have explicit permission to test
- Respect rate limits and avoid aggressive scanning
- Follow responsible disclosure practices
- Comply with bug bounty program rules and scope

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This script leverages amazing open-source tools:

- [Subfinder](https://github.com/projectdiscovery/subfinder) by ProjectDiscovery
- [PureDNS](https://github.com/d3mondev/puredns) by d3mondev
- [httpX](https://github.com/projectdiscovery/httpx) by ProjectDiscovery
- [Naabu](https://github.com/projectdiscovery/naabu) by ProjectDiscovery
- [Subjack](https://github.com/haccer/subjack) by haccer
- [TruffleHog](https://github.com/trufflesecurity/trufflehog) by Truffle Security
- [Nmap](https://nmap.org/) by Gordon Lyon
- [WhatWeb](https://github.com/urbanadventurer/WhatWeb) by urbanadventurer

## 📧 Contact

For questions or suggestions, feel free to open an issue on GitHub.

---

**Happy Hacking! 🎯**
