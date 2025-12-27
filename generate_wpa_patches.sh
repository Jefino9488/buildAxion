#!/usr/bin/env bash
# Purpose: Generate .patch files from the WPA supplicant commits
# Run this after first sync to create proper patch files for version control
#
# Usage: ./generate_wpa_patches.sh <source_dir>

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PATCHES_DIR="${SCRIPT_DIR}/patches/external_wpa_supplicant_8"

log()   { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <source_dir>"
  echo "Example: $0 ~/axionos"
  exit 1
fi

SOURCE_DIR="$1"
WPA_DIR="${SOURCE_DIR}/external/wpa_supplicant_8"

if [[ ! -d "$WPA_DIR/.git" ]]; then
  error "Not found: $WPA_DIR"
fi

mkdir -p "$PATCHES_DIR"

cd "$WPA_DIR"

log "Fetching Nothing-2A wpa_supplicant_8 for patches..."
git fetch https://github.com/Nothing-2A/android_external_wpa_supplicant_8

# Generate patches
log "Generating patch files..."

# Patch 1: MediaTek changes
git format-patch -1 39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048 \
  --start-number=1 \
  -o "$PATCHES_DIR"
  
# Rename to descriptive name
mv "$PATCHES_DIR"/0001-*.patch "$PATCHES_DIR/0001-mtk-wpa-changes.patch" 2>/dev/null || true

# Patch 2: Enable WAPI
git format-patch -1 37a6e255d9d68fb483d12db550028749b280509b \
  --start-number=2 \
  -o "$PATCHES_DIR"
  
# Rename to descriptive name  
mv "$PATCHES_DIR"/0002-*.patch "$PATCHES_DIR/0002-enable-wapi.patch" 2>/dev/null || true

# Clean up the placeholder
rm -f "$PATCHES_DIR/.gitkeep"

log ""
log "Generated patches:"
ls -la "$PATCHES_DIR"/*.patch

log ""
log "Patches are now version-controlled in:"
log "  ${PATCHES_DIR}"
log ""
log "These will be applied automatically by ./apply_patches.sh"
