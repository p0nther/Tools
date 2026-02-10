# Enhanced Modular Recon Script v3.0 - Usage Guide

## 🎯 Quick Start

```bash
# Full reconnaissance (quiet mode)
./recon.sh example.com --all

# Full reconnaissance with custom resolvers (recommended)
./recon.sh example.com --all --resolvers resolvers.txt

# Full reconnaissance including manual/noisy operations
./recon.sh example.com --all --manual --resolvers resolvers.txt

# With GitHub secrets scanning
./recon.sh example.com --all --github example-org --resolvers resolvers.txt
```

## 📋 What Changed from v2.0

### ❌ Removed Issues

1. **No more blind scanning** - nmap/whatweb moved to `--manual` flag
2. **No more unreliable DNS** - supports custom resolvers via `--resolvers`
3. **No more httpx port scanning** - httpx only checks default HTTP ports
4. **No more noisy defaults** - naabu uses top 100 ports by default
5. **No more false positives** - subjack uses HTTP-reachable hosts only
6. **True modularity** - stage flags, resume, skip capabilities

### ✅ New Features

- **Stage-based execution** with individual flags
- **Resume capability** to continue interrupted scans
- **Skip stages** to avoid re-running completed work
- **Custom resolvers** for better DNS accuracy
- **Top ports by default** with opt-in full scan
- **Two-pass httpx** for discovered HTTP ports
- **State tracking** for resume functionality

## 🚀 Usage Examples

### Basic Usage

```bash
# Run specific stages
./recon.sh example.com --subs --dns --web

# Run all stages except secrets
./recon.sh example.com --all

# Run all stages including GitHub scanning
./recon.sh example.com --all --github example-org
```

### Advanced Usage

```bash
# Full scan with custom resolvers (RECOMMENDED)
./recon.sh example.com --all --resolvers /path/to/resolvers.txt

# Full port scan (all 65535 ports - slow!)
./recon.sh example.com --ports --full-ports

# Include manual/noisy operations
./recon.sh example.com --all --manual

# Custom concurrency and rate limiting
./recon.sh example.com --all --threads 100 --rate-limit 300

# Scan top 1000 ports instead of default 100
./recon.sh example.com --ports --top-ports 1000
```

### Resume & Skip

```bash
# Start a scan
./recon.sh example.com --all

# [Interrupted with Ctrl+C]

# Resume from last completed stage
./recon.sh example.com --resume

# Skip specific stages
./recon.sh example.com --all --skip dns,secrets

# Skip manual operations even if --manual is set
./recon.sh example.com --all --manual --skip manual
```

## 📊 Stage Breakdown

### Stage 1: Subdomain Enumeration (`--subs`)
- Tool: **subfinder**
- Output: `subs/subdomains_raw.txt`
- Speed: Fast
- Noise: Low

### Stage 2: DNS Validation (`--dns`)
- Tool: **puredns**
- Output: `dns/subdomains_validated.txt`, `dns/subdomains_ips.txt`
- Speed: Medium
- Noise: Low
- **Recommendation**: Use `--resolvers` for production

### Stage 3: Web Probing (`--web`)
- Tool: **httpx**
- Ports: 80, 443, 8080, 8443 only
- Output: `web/live_subdomains.txt`
- Speed: Fast
- Noise: Low

### Stage 4: Port Scanning (`--ports`)
- Tool: **naabu**
- Default: Top 100 ports
- Full scan: Use `--full-ports` (65535 ports)
- Output: `ports/all_ports.txt`
- Speed: Fast (top ports) / Slow (full)
- Noise: Low (top ports) / High (full)
- **Note**: Automatically runs second httpx pass on discovered HTTP ports

### Stage 5: Subdomain Takeover (`--takeover`)
- Tool: **subjack**
- Input: HTTP-reachable hosts from httpx
- Output: `takeover/subjack_results.txt`
- Speed: Medium
- Noise: Low

### Stage 6: GitHub Secrets (`--secrets`)
- Tool: **trufflehog**
- Requires: `--github <org-name>`
- Output: `secrets/github_secrets.json`
- Speed: Slow
- Noise: None (API-based)

### Manual Stage (`--manual`)
- Tools: **whatweb**, **nmap**
- Output: `manual/whatweb.txt`, `manual/nmap_scan.txt`
- Speed: Slow
- Noise: **HIGH** ⚠️
- **Warning**: Only use when necessary, can trigger IDS/IPS

## 🔧 Configuration Options

```bash
--resolvers <file>     Path to trusted DNS resolvers (highly recommended)
--github <org>         GitHub organization to scan
--threads <n>          Concurrency level (default: 50)
--timeout <n>          Request timeout in seconds (default: 10)
--rate-limit <n>       Requests per second (default: 150)
--top-ports <n>        Number of top ports to scan (default: 100)
--full-ports           Scan all 65535 ports (slow, noisy)
```

## 📁 Output Structure

```
example.com/
├─ subs/
│  └─ subdomains_raw.txt          # Raw subfinder output
├─ dns/
│  ├─ subdomains_validated.txt    # DNS-validated subdomains
│  ├─ subdomains_ips.txt          # Extracted IP addresses
│  └─ resolvers.txt               # Resolvers used
├─ web/
│  ├─ live_subdomains.txt         # Live web services (httpx)
│  ├─ live_hosts.txt              # Unique hosts
│  └─ httpx_discovered_ports.txt  # Second httpx pass results
├─ ports/
│  ├─ all_ports.txt               # All open ports (naabu)
│  └─ http_ports.txt              # HTTP-related ports
├─ takeover/
│  └─ subjack_results.txt         # Subdomain takeover findings
├─ secrets/
│  └─ github_secrets.json         # GitHub secrets (if scanned)
├─ manual/
│  ├─ whatweb.txt                 # Tech fingerprinting
│  └─ nmap_scan.txt               # Nmap results
├─ logs/
│  └─ all_info.txt                # Complete execution log
└─ .state                         # Resume state tracking
```

## 💡 Best Practices

### For Bug Bounty / VRP

```bash
# Recommended workflow
./recon.sh target.com --all --resolvers resolvers.txt --github target-org

# Avoid noisy operations unless necessary
# Don't use --manual or --full-ports unless you have permission
```

### For CTF / Lab Environments

```bash
# You can be more aggressive
./recon.sh target.thm --all --manual --full-ports
```

### For Large Targets

```bash
# Start with quiet recon
./recon.sh target.com --subs --dns --web --resolvers resolvers.txt

# Analyze results, then decide on port scanning
./recon.sh target.com --ports --top-ports 1000

# Only run full scan on interesting hosts manually
```

## 🔄 Resume Workflow

The script automatically tracks completed stages in `.state` file:

```bash
# Start scan
./recon.sh example.com --all

# Interrupt (Ctrl+C)

# Resume automatically
./recon.sh example.com --resume

# Or resume with different flags
./recon.sh example.com --resume --full-ports
```

## ⚠️ Important Notes

1. **Always use custom resolvers** for production (`--resolvers`)
2. **Avoid `--manual`** unless you have explicit permission
3. **Avoid `--full-ports`** on large targets (use top ports first)
4. **Use `--resume`** if scan is interrupted
5. **Check `.state` file** to see completed stages

## 🎓 Learning Path

1. **Start simple**: `./recon.sh target.com --subs --dns`
2. **Add web probing**: `./recon.sh target.com --subs --dns --web`
3. **Add port scanning**: `./recon.sh target.com --all`
4. **Optimize**: Add `--resolvers`, adjust `--threads`, `--rate-limit`
5. **Advanced**: Use `--manual` only when needed

## 📞 Troubleshooting

### "No subdomains found"
- Check if domain is correct
- Try different subfinder sources
- Check internet connection

### "Missing tools"
- Install with: `go install -v github.com/projectdiscovery/<tool>/cmd/<tool>@latest`

### "DNS validation failed"
- Use custom resolvers: `--resolvers resolvers.txt`
- Check resolver file format (one IP per line)

### "Port scan too slow"
- Reduce `--top-ports` number
- Increase `--rate-limit`
- Don't use `--full-ports` unless necessary

## 🎯 Next Steps After Recon

1. **Analyze results**: Review `logs/all_info.txt`
2. **Prioritize targets**: Focus on interesting subdomains/ports
3. **Manual testing**: Test each service individually
4. **Take notes**: Document credentials, admin panels, APIs
5. **Iterate**: Re-run specific stages as needed

Happy Hacking! 🎯
