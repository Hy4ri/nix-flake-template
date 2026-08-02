#!/usr/bin/env bash
#
# update-version.sh — update version.json + package.nix for a new release.
#
# Usage: ./update-version.sh [version]
#   version   Required. The new version (the workflow passes it from
#             check-update.sh). You can also wire an auto-fetch here.
#
# Customize DOWNLOAD_URL_TEMPLATE: the URL of the archive to hash.
# $version is interpolated. The archive is downloaded once and its sha256
# becomes the SRI hash in package.nix (version.json keeps the version).
#
# This is the simplest fleet pattern (single-archive, single platform).
# For multi-platform/multi-channel packages, adapt from the fleet:
#   - opencode: per-platform assets, hash each, write per-platform hashes
#   - fluxer:   per-channel (stable/canary) × per-arch manifests,
#               prefer API-provided sha256, download as fallback
#   - antigravity: nested version.json {cli, hub, ide, sdk} with
#               per-component hashes + semver-aware comparison (sort -V)

set -euo pipefail

version="${1:-}"
if [ -z "$version" ]; then
  echo "Error: version argument required (e.g. ./update-version.sh 1.2.3)" >&2
  exit 1
fi

# ← CHANGE THIS: archive URL for $version
DOWNLOAD_URL_TEMPLATE="https://github.com/OWNER/REPO/releases/download/v${version}/myapp-${version}.tar.gz"

get_sri_hash() {
  local url="$1" temp_file raw_hash
  temp_file="$(mktemp)"
  trap 'rm -f "$temp_file"' RETURN
  curl -fsSL --connect-timeout 10 --max-time 120 --retry 3 --retry-delay 3 --retry-all-errors "$url" -o "$temp_file"
  raw_hash=$(sha256sum "$temp_file" | cut -d' ' -f1)
  nix hash convert --hash-algo sha256 --to sri "$raw_hash"
}

echo "------------------------------------------------"
echo "Target Version: $version"
echo "------------------------------------------------"

echo "Downloading and hashing: $DOWNLOAD_URL_TEMPLATE"
hash_sri=$(get_sri_hash "$DOWNLOAD_URL_TEMPLATE")
[ -n "$hash_sri" ] || { echo "Error: failed to hash archive." >&2; exit 1; }
echo "  SRI: $hash_sri"

echo "Updating package.nix ..."
temp_file=$(mktemp)
sed "s/version = \".*\";/version = \"$version\";/" package.nix > "$temp_file"
sed -i "s|hash = \"sha256-.*\";|hash = \"$hash_sri\";|" "$temp_file"
mv "$temp_file" package.nix

echo "Updating version.json ..."
cat > version.json << EOF
{
  "version": "$version"
}
EOF

echo "------------------------------------------------"
echo "Success! Updated to version ${version}"
echo "------------------------------------------------"
