#!/usr/bin/env bash
# Purpose: Sync AxionOS/AOSP sources using local manifests
# Uses professional AOSP patterns: local manifests, patches, forked repos
# Safe to re-run (idempotent)

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Configuration (can be overridden via env vars or .env file)
AXION_REMOTE_URL=${AXION_REMOTE_URL:-"https://github.com/AxionAOSP/android.git"}
AXION_BRANCH=${AXION_BRANCH:-"lineage-23.1"}
WORKDIR=${WORKDIR:-"axionos"}
THREADS=${THREADS:-"6"}
WITH_MIUI_CAM=${WITH_MIUI_CAM:-"false"}
APPLY_WPA_PATCHES=${APPLY_WPA_PATCHES:-"false"}
GIT_USER_NAME=${GIT_USER_NAME:-"Jefino9488"}
GIT_USER_EMAIL=${GIT_USER_EMAIL:-"jefino9488@gmail.com"}

log()   { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not found. Install it first or run ./setup_build_env.sh"
}

usage() {
  cat <<EOF
${SCRIPT_NAME} - Sync AxionOS sources using local manifests

This script uses the professional AOSP pattern:
  1. repo init with AxionAOSP manifest
  2. Copy local_manifests/ to .repo/local_manifests/
  3. repo sync (fetches everything including your device trees)
  4. Apply patches from patches/ directory

Env vars / Flags:
  WORKDIR=<path>            Working directory (default: axionos)
  THREADS=<n>               repo sync jobs (default: 6)
  WITH_MIUI_CAM=true        Include MIUI camera tree (default: false)
  APPLY_WPA_PATCHES=true    Apply WPA patches after sync (default: false)

Examples:
  ${SCRIPT_NAME}
  WORKDIR=\$HOME/axionos ${SCRIPT_NAME}
  WITH_MIUI_CAM=true APPLY_WPA_PATCHES=true ${SCRIPT_NAME}
EOF
}

setup_local_manifests() {
  local dest=".repo/local_manifests"
  
  log "Setting up local manifests..."
  mkdir -p "$dest"
  
  # Always copy the main xaga.xml
  if [[ -f "${SCRIPT_DIR}/local_manifests/xaga.xml" ]]; then
    cp "${SCRIPT_DIR}/local_manifests/xaga.xml" "$dest/"
    log "  ✓ Copied xaga.xml"
  else
    warn "  xaga.xml not found in ${SCRIPT_DIR}/local_manifests/"
  fi
  
  # Conditionally copy MIUI camera manifest
  if [[ "$WITH_MIUI_CAM" == "true" ]]; then
    if [[ -f "${SCRIPT_DIR}/local_manifests/miui_camera.xml" ]]; then
      cp "${SCRIPT_DIR}/local_manifests/miui_camera.xml" "$dest/"
      log "  ✓ Copied miui_camera.xml (MIUI camera enabled)"
    fi
  else
    # Remove if exists (in case user disabled it)
    rm -f "$dest/miui_camera.xml" 2>/dev/null || true
    log "  ⊘ MIUI camera disabled"
  fi
  
  # List what's in local_manifests
  log "  Local manifests:"
  ls -la "$dest"/*.xml 2>/dev/null | while read -r line; do
    log "    $line"
  done
}

apply_patches() {
  if [[ -x "${SCRIPT_DIR}/apply_patches.sh" ]]; then
    log "Applying patches..."
    "${SCRIPT_DIR}/apply_patches.sh" "$(pwd)"
  else
    warn "apply_patches.sh not found or not executable. Skipping patches."
  fi
}

# Legacy: apply WPA patches via cherry-pick if patches not available
apply_wpa_patches_legacy() {
  local dir="external/wpa_supplicant_8"
  if [[ ! -d "$dir/.git" ]]; then
    warn "Cannot find $dir. Skipping WPA patches."
    return 0
  fi
  
  # Check if we have proper .patch files
  if [[ -d "${SCRIPT_DIR}/patches/external_wpa_supplicant_8" ]] && \
     ls "${SCRIPT_DIR}/patches/external_wpa_supplicant_8"/*.patch >/dev/null 2>&1; then
    log "WPA patches will be applied via apply_patches.sh"
    return 0
  fi
  
  # Fallback to legacy cherry-pick method
  warn "Using legacy cherry-pick method for WPA patches."
  warn "Consider generating proper .patch files for version control."
  
  pushd "$dir" >/dev/null
  log "Fetching WPA patch source..."
  git fetch https://github.com/Nothing-2A/android_external_wpa_supplicant_8 || true
  
  for commit in \
    39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048 \
    37a6e255d9d68fb483d12db550028749b280509b; do
    if git merge-base --is-ancestor "$commit" HEAD 2>/dev/null; then
      log "Patch $commit already present."
    else
      log "Applying patch $commit"
      if ! git cherry-pick "$commit"; then
        warn "Conflict applying $commit. Aborting cherry-pick and skipping."
        git cherry-pick --abort || true
      fi
    fi
  done
  popd >/dev/null
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  need_cmd git
  need_cmd curl
  need_cmd repo

  # Configure git identity if not already set (required for repo init)
  if ! git config --global user.name >/dev/null 2>&1; then
    log "Configuring git user.name: $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
  fi
  if ! git config --global user.email >/dev/null 2>&1; then
    log "Configuring git user.email: $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
  fi

  log "Using workdir: $WORKDIR"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  # ========== Step 1: repo init ==========
  if [[ -d .repo ]]; then
    log "Repo already initialized. Skipping repo init."
  else
    log "Initializing repo: $AXION_REMOTE_URL ($AXION_BRANCH)"
    repo init -u "$AXION_REMOTE_URL" -b "$AXION_BRANCH" --depth=1 --git-lfs
  fi

  # ========== Step 2: Setup local manifests ==========
  setup_local_manifests

  # ========== Step 3: repo sync ==========
  local sync_threads=${THREADS:-6}
  if (( sync_threads > 6 )); then sync_threads=6; fi
  
  log "Syncing sources with $sync_threads threads..."
  log "This will fetch AxionOS base + all device trees from local manifests"
  repo sync -c --no-tags --no-clone-bundle -j"$sync_threads"

  # ========== Step 4: Apply patches ==========
  apply_patches
  
  # Legacy WPA patches (if enabled and .patch files not available)
  if [[ "$APPLY_WPA_PATCHES" == "true" ]]; then
    apply_wpa_patches_legacy
  fi

  # ========== Done ==========
  log ""
  log "=========================================="
  log "  Sync Complete!"
  log "=========================================="
  log ""
  log "Your forked repos (push access):"
  log "  • device/xiaomi/xaga"
  log "  • device/xiaomi/mt6895-common"
  log "  • device/mediatek/sepolicy_vndr"
  log ""
  log "To make changes and push:"
  log "  cd device/xiaomi/xaga"
  log "  # make your edits..."
  log "  git add . && git commit -m 'Your change'"
  log "  git push origin HEAD:lineage-23.1"
  log ""
  log "Next steps:"
  cat <<'STEPS'
  1) . build/envsetup.sh
  2) If first build only: gk -s
  3) Choose device/variant:
       axion xaga              # default: gms core
       axion xaga gms pico     # minimal Google apps
       axion xaga va           # vanilla
  4) Build:
       ax -br -j$(nproc --all)
STEPS
}

main "$@"
