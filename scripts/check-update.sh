#!/usr/bin/env bash
#
# check-update.sh — the ONLY project-specific piece of the update pipeline.
#
# The workflow (.github/workflows/update.yml) calls this script and reads
# its outputs. Contract:
#
#   SUCCESS + update available:
#     echo "update_needed=true"  >> $GITHUB_OUTPUT
#     echo "version=<new>"       >> $GITHUB_OUTPUT
#   SUCCESS + already current:
#     echo "update_needed=false" >> $GITHUB_OUTPUT
#   FAILURE (any fetch/parse problem):
#     die "human readable reason"   (writes fail_reason + exits 1)
#
# The auto-issue machinery (report-failure job, dedupe, auto-close) and the
# hardened fetches (scripts/lib/network.sh) are shared — you only write the
# "what is the latest version" part here.
#
# ─────────────────────────────────────────────────────────────────────
# Default: GitHub Releases API — the most reliable source in the fleet.
# Copy this repo and change REPO below, done.
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/network.sh"

# ← CHANGE THIS: owner/name of the project this flake packages
REPO="OWNER/REPO"

# ── Alternative sources (swap the block below) ─────────────────────
# HTTP version endpoint (kimicode pattern):
#   LATEST_VERSION=$(fetch_url "https://example.com/api/latest" | tr -d '[:space:]')
#
# Page scrape (cheatengine pattern):
#   LATEST_VERSION=$(fetch_url "https://example.com/downloads" |
#     grep -oP 'myapp_\K[0-9.]+(?=\.zip)' | sort -V | tail -n 1)
#
# Multi-channel / multi-component (fluxer / antigravity / Vivaldi):
#   keep one die() per channel/component, write fail_reason per failure,
#   and set update_needed=true if ANY of them changed.
# ─────────────────────────────────────────────────────────────────────

echo "Fetching latest version..."
LATEST_VERSION=""
if ! LATEST_VERSION=$(fetch_gh_api "repos/$REPO/releases/latest" --jq '.tag_name | ltrimstr("v")'); then
  die "Could not fetch latest version from GitHub API after 3 attempts. Last error: $(tail -n 1 "$ERR_LOG" 2>/dev/null || echo 'unknown')"
fi
[ -n "$LATEST_VERSION" ] || die "GitHub API returned an empty version."

CURRENT_VERSION=$(jq -r '.version' version.json)
echo "Latest: $LATEST_VERSION"
echo "Current: $CURRENT_VERSION"

if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
  echo "New version available!"
  echo "update_needed=true" >> "$GITHUB_OUTPUT"
  echo "version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
else
  echo "update_needed=false" >> "$GITHUB_OUTPUT"
fi
