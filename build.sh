#!/usr/bin/env bash
set -euo pipefail

### CONFIG ##########################################################

WORKDIR="./adblock_build"
OUTFILE="ruleset.conf"

# Blacklist sources (hosts format)
BLACKLIST_URLS=(
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/multi-compressed.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif.medium-onlydomains.txt"
  "https://cdn.jsdelivr.net/gh/badmojr/1Hosts@master/Lite/domains.txt"
)

# Whitelist source (domain per line)
WHITELIST_URL="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/whitelist-referral.txt"

###################################################################

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[*] Downloading blacklists..."
> blacklists.raw
for url in "${BLACKLIST_URLS[@]}"; do
  curl -fsSL "$url" >> blacklists.raw
  echo >> blacklists.raw
done

echo "[*] Downloading whitelist..."
if ! curl -fsSL "$WHITELIST_URL" > whitelist.raw; then
  echo "[!] Whitelist download failed — continuing with empty whitelist"
  : > whitelist.raw
fi

echo "[*] Normalizing blacklist → domain only..."
sed '
  s/#.*//;
  s/\r//;
  s/^[0-9.:]\+\s\+//;
  s/\s\+.*$//;
  s/^localhost$//;
  /^\s*$/d;
' blacklists.raw \
| tr 'A-Z' 'a-z' \
| grep -E '^[a-z0-9.-]+$' \
| sort -u \
> blacklist.domains

echo "[*] Normalizing whitelist..."
sed '
  s/#.*//;
  s/\r//;
  /^\s*$/d;
' whitelist.raw \
| tr 'A-Z' 'a-z' \
| sort -u \
> whitelist.domains

echo "[*] Removing whitelisted domains from blacklist..."
comm -23 blacklist.domains whitelist.domains > blacklist.filtered

echo "[*] Converting to Surfboard ruleset format..."
awk '{ print "DOMAIN," $1 ",REJECT" }' blacklist.filtered > "$OUTFILE"

echo "[✓] Done!"
echo "[✓] Output file: $WORKDIR/$OUTFILE"
echo "[✓] Total rules: $(wc -l < "$OUTFILE")"
