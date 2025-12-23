#!/usr/bin/env bash
# Purpose: Sync AxionOS/AOSP sources and clone xaga device dependencies
# Safe to re-run (idempotent where possible)

set -euo pipefail

SCRIPT_NAME=$(basename "$0")

AXION_REMOTE_URL=${AXION_REMOTE_URL:-"https://github.com/AxionAOSP/android.git"}
AXION_BRANCH=${AXION_BRANCH:-"lineage-23.0"}
WORKDIR=${WORKDIR:-"axionos"}
THREADS=${THREADS:-"$(nproc --all)"}
WITH_MIUI_CAM=${WITH_MIUI_CAM:-"false"}
APPLY_WPA_PATCHES=${APPLY_WPA_PATCHES:-"false"}

log()   { echo -e "[INFO]  $*"; }
warn()  { echo -e "[WARN]  $*" >&2; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not found. Install it first or run ./setup_build_env.sh"
}

usage() {
  cat <<EOF
${SCRIPT_NAME} - Sync AxionOS sources and clone device trees for xaga

Env vars / Flags:
  WORKDIR=<path>            Working directory (default: axionos)
  THREADS=<n>               repo sync jobs (default: nproc)
  WITH_MIUI_CAM=true        Also clone optional MIUI camera tree (default: false)
  APPLY_WPA_PATCHES=true    Apply wpa_supplicant_8 patches (default: false)

Examples:
  ${SCRIPT_NAME}
  WORKDIR=$HOME/axionos ${SCRIPT_NAME}
  WITH_MIUI_CAM=true APPLY_WPA_PATCHES=true ${SCRIPT_NAME}
EOF
}

clone_if_missing() {
  local url="$1"; shift
  local dest="$1"; shift
  if [[ -d "$dest/.git" ]]; then
    log "Exists: $dest"
  else
    log "Cloning $url -> $dest"
    mkdir -p "$(dirname "$dest")"
    git clone --depth=1 "$url" "$dest"
  fi
}

apply_wpa_patches() {
  local dir="external/wpa_supplicant_8"
  if [[ ! -d "$dir/.git" ]]; then
    warn "Cannot find $dir. Skipping WPA patches."
    return 0
  fi
  pushd "$dir" >/dev/null
  log "Fetching WPA patch source..."
  git fetch https://github.com/Nothing-2A/android_external_wpa_supplicant_8 || true
  # Try cherry-picks; ignore if already applied
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

  log "Using workdir: $WORKDIR"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  if [[ -d .repo ]]; then
    log "Repo already initialized. Skipping repo init."
  else
    log "Initializing repo: $AXION_REMOTE_URL ($AXION_BRANCH)"
    repo init -u "$AXION_REMOTE_URL" -b "$AXION_BRANCH" --git-lfs
  fi

  log "Syncing sources with $THREADS threads..."
  repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j"$THREADS"

  log "Cloning device/kernel/vendor/hardware trees for xaga..."
  clone_if_missing https://github.com/XagaForge/android_device_xiaomi_xaga device/xiaomi/xaga
  clone_if_missing https://github.com/XagaForge/android_device_xiaomi_mt6895-common device/xiaomi/mt6895-common
  clone_if_missing https://github.com/XagaForge/android_kernel_xiaomi_mt6895 kernel/xiaomi/mt6895

  clone_if_missing https://gitlab.com/priiii08918/android_vendor_xiaomi_xaga vendor/xiaomi/xaga
  clone_if_missing https://github.com/XagaForge/android_vendor_xiaomi_mt6895-common vendor/xiaomi/mt6895-common
  clone_if_missing https://github.com/XagaForge/android_vendor_firmware vendor/firmware

  clone_if_missing https://github.com/XagaForge/android_hardware_xiaomi hardware/xiaomi
  clone_if_missing https://github.com/XagaForge/android_hardware_mediatek hardware/mediatek

  clone_if_missing https://github.com/XagaForge/android_device_mediatek_sepolicy_vndr device/mediatek/sepolicy_vndr
  clone_if_missing https://github.com/XagaForge/android_vendor_mediatek_ims vendor/mediatek/ims

  if [[ "$WITH_MIUI_CAM" == "true" ]]; then
    clone_if_missing https://gitlab.com/priiii1808/proprietary_vendor_xiaomi_miuicamera-xaga.git vendor/xiaomi/miuicamera-xaga
  else
    log "Skipping optional MIUI camera tree. Set WITH_MIUI_CAM=true to include."
  fi

  if [[ "$APPLY_WPA_PATCHES" == "true" ]]; then
    apply_wpa_patches
  else
    log "Skipping WPA patches. Set APPLY_WPA_PATCHES=true to apply."
  fi

  log "Done. Next steps (from README):"
  cat <<'STEPS'
  1) . build/envsetup.sh
  2) If first build only: gk -s
  3) Choose device/variant, e.g.:
       axion xaga            # default: gms core
       axion xaga gms pico   # minimal Google apps
       axion xaga va         # vanilla
  4) Build:
       ax -br -j$(nproc --all)
STEPS

  log "To update sources later, you can run 'axionSync' from within the tree (if available), or re-run this script."
}

main "$@"
