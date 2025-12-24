#!/usr/bin/env bash
# Purpose: Prepare a Linux host to build Android/AOSP and AxionOS
# Focus: install/update required packages, tools (repo, git lfs), and helpful utilities

set -euo pipefail

SCRIPT_NAME=$(basename "$0")

log()   { echo -e "[INFO]  $*"; }
warn()  { echo -e "[WARN]  $*" >&2; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not found. Please install it and re-run."
}

ensure_repo_tool() {
  if command -v repo >/dev/null 2>&1; then
    log "repo tool already present: $(command -v repo)"
    return 0
  fi
  local dest="$HOME/bin/repo"
  mkdir -p "$HOME/bin"
  log "Installing Google's 'repo' tool to $dest"
  curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$dest"
  chmod +x "$dest"
  if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    log "Adding $HOME/bin to PATH in ~/.bashrc"
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    warn "Added $HOME/bin to your PATH. Please run 'source ~/.bashrc' or restart your shell."
  fi
}

install_debian_based() {
  need_cmd sudo
  log "Enabling i386 architecture..."
  sudo dpkg --add-architecture i386 || true
  log "Updating apt package index..."
  sudo apt-get update -y
  log "Installing base build dependencies (Debian/Ubuntu)..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git git-core git-lfs curl wget ca-certificates gnupg \
    openjdk-17-jdk \
    build-essential bc bison flex gperf zip unzip \
    ccache lzop schedtool \
    python3 python3-pip \
    zlib1g-dev libncurses6 libncurses-dev libtinfo6 \
    libssl-dev libxml2-utils xsltproc fontconfig \
    rsync coreutils file make cmake ninja-build pkg-config \
    adb android-tools-adb imagemagick pngcrush \
    libsdl1.2-dev lz4 libgl1-mesa-dev \
    lib32ncurses-dev lib32readline-dev lib32z1-dev libc6-dev-i386 \
    x11proto-core-dev libx11-dev \
    squashfs-tools yasm \
    jq aria2 \
    netcat-openbsd \
    rclone

  # Optional but useful
  log "Installing optional helpers (useful for some trees/scripts)..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git-extras \
    locales \
    clang \
    lld \
    patchelf

  log "Ensuring git-lfs is initialized..."
  git lfs install --skip-repo || true

  ensure_repo_tool
}

install_arch() {
  need_cmd sudo
  log "Refreshing pacman package databases..."
  sudo pacman -Syy --noconfirm
  log "Installing base build dependencies (Arch)..."
  sudo pacman -S --needed --noconfirm \
    git git-lfs curl wget ca-certificates gnupg \
    jdk17-openjdk \
    base-devel bc bison flex gperf zip unzip \
    ccache lzop \
    python python-pip \
    zlib ncurses \
    libxml2 xsltproc \
    rsync file cmake ninja pkgconf \
    jq aria2 \
    openbsd-netcat \
    rclone

  log "Initializing git-lfs..."
  git lfs install --skip-repo || true

  ensure_repo_tool

  warn "If kernel build complains about libyaml on Arch, see README 'Fix for Arch Linux Users'."
}

detect_os_and_install() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID_LIKE:-$ID}" in
      *debian*|*ubuntu*) install_debian_based ;;
      *arch*|*manjaro*)  install_arch ;;
      *)
        warn "Unrecognized distro family: ${ID_LIKE:-$ID}. Attempting Debian/Ubuntu flow."
        install_debian_based
        ;;
    esac
  else
    warn "/etc/os-release not found. Attempting Debian/Ubuntu flow."
    install_debian_based
  fi
}

usage() {
  cat <<EOF
${SCRIPT_NAME} - Prepare this machine for Android/AOSP & AxionOS builds

Usage: ${SCRIPT_NAME}

What it does:
  - Installs required packages (Debian/Ubuntu or Arch based)
  - Installs/updates 'repo' tool to \$HOME/bin
  - Initializes git-lfs
  - Installs helpers used by README and common Android build flows

After this, proceed with source sync using: ./setup_xaga_env.sh
EOF
}

setup_build_volume() {
  local device="${BUILD_VOLUME_DEVICE:-}"
  if [[ -z "$device" ]]; then
    return 0
  fi

  if mountpoint -q /build 2>/dev/null; then
    log "/build is already a mountpoint. Skipping setup."
    return 0
  fi

  log "Setting up build volume on $device..."
  if ! lsblk "$device" >/dev/null 2>&1; then
    warn "Device $device not found! Skipping build volume setup."
    return 0
  fi

  # Check if it has a filesystem
  if ! sudo blkid "$device" >/dev/null 2>&1; then
    log "Formatting $device as ext4..."
    sudo mkfs.ext4 "$device"
  fi

  sudo mkdir -p /build
  log "Mounting $device to /build..."
  sudo mount "$device" /build || { warn "Failed to mount $device"; return 1; }
  sudo chown -R "$USER:$USER" /build

  # Persist in fstab
  local uuid
  uuid=$(sudo blkid -s UUID -o value "$device")
  if [[ -n "$uuid" ]] && ! grep -q "$uuid" /etc/fstab; then
    log "Adding /build to /etc/fstab..."
    echo "UUID=$uuid /build ext4 defaults,noatime,discard 0 2" | sudo tee -a /etc/fstab
  fi
}

optimize_host() {
  log "Optimizing host for 16GB RAM / 8 vCPU / Android 16 AOSP (MTK) profile..."

  # =========================================================================
  # FINAL LAYOUT (from optimization guide):
  #   /                → AOSP source + out/ (320 GB)
  #   /mnt/ccache      → ccache (100 GB volume)
  #   /mnt/scratch     → dist / zips / backups (100 GB volume)
  #   swap             → 64 GB
  # ⚠️ out/ MUST stay on root. Never put out/ on a 100 GB volume.
  # =========================================================================

  # Build volume if requested via BUILD_VOLUME_DEVICE (legacy path)
  setup_build_volume

  # Swap: 64GB (on root disk)
  if swapon --show | grep -q "/swapfile"; then
    log "Swapfile already exists. Skipping creation."
  else
    log "Creating 64GB swapfile (this may take a while)..."
    # Try fallocate first (fast), fallback to dd
    sudo fallocate -l 64G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=65536
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
      echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
  fi

  # Tune VM for Android 16 AOSP build
  log "Tuning VM parameters (swappiness=60, vfs_cache_pressure=50)..."
  sudo sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
  sudo sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1 || true
  # Persist in sysctl.conf
  if ! grep -q "vm.swappiness=60" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.swappiness=60" | sudo tee -a /etc/sysctl.conf >/dev/null
  fi
  if ! grep -q "vm.vfs_cache_pressure=50" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf >/dev/null
  fi

  # Ccache: 90GB on /mnt/ccache (100GB volume with margin)
  # Check if /mnt/ccache is mounted, else fallback to legacy paths
  local ccache_dir="$HOME/.ccache"
  if mountpoint -q /mnt/ccache 2>/dev/null; then
    ccache_dir="/mnt/ccache"
    log "Using dedicated ccache volume at $ccache_dir"
  elif [[ -d /mnt/ccache ]]; then
    ccache_dir="/mnt/ccache"
    log "Using /mnt/ccache directory for ccache"
  elif [[ -d /build ]]; then
    ccache_dir="/build/ccache"
    mkdir -p "$ccache_dir"
  fi

  if command -v ccache >/dev/null 2>&1; then
    log "Setting ccache max size to 90GB and directory to $ccache_dir..."
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    export CCACHE_DIR="$ccache_dir"
    ccache -M 90G
    ccache -z  # Reset stats
    
    # Persist in .bashrc if not already there
    if ! grep -q "export CCACHE_DIR" ~/.bashrc; then
      {
        echo ""
        echo "# ccache settings for Android build"
        echo "export USE_CCACHE=1"
        echo "export CCACHE_EXEC=/usr/bin/ccache"
        echo "export CCACHE_DIR=$ccache_dir"
      } >> ~/.bashrc
      log "Persisted ccache settings in ~/.bashrc"
    fi
  else
    warn "ccache not found, skipping size configuration."
  fi

  # Java + Build limits (Anti-OOM) for 16GB RAM / 8 vCPU
  # Uses THREADS env var (default: 6) so editing .env_xaga changes everything
  local build_threads="${THREADS:-6}"
  log "Setting Java and build limits for OOM prevention (using -j$build_threads)..."
  
  # Remove old settings if present (to allow updates when THREADS changes)
  sed -i '/_JAVA_OPTIONS/d; /JAVA_TOOL_OPTIONS/d; /SOONG_BUILD_NINJA_ARGS/d; /NINJA_ARGS/d; /MAKEFLAGS.*-j/d' ~/.bashrc 2>/dev/null || true
  
  {
    echo ""
    echo "# Java options for Android build (OOM prevention)"
    echo 'export _JAVA_OPTIONS="-Xmx6g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"'
    echo 'export JAVA_TOOL_OPTIONS="$_JAVA_OPTIONS"'
    echo ""
    echo "# Build limits (controlled by THREADS env var, default: 6)"
    echo "export SOONG_BUILD_NINJA_ARGS=\"-j$build_threads\""
    echo "export NINJA_ARGS=\"-j$build_threads\""
    echo "export MAKEFLAGS=\"-j$build_threads\""
  } >> ~/.bashrc
  log "Persisted Java/build limit settings in ~/.bashrc (-j$build_threads)"

  # Setup scratch directory for dist/zips/backups if available
  if mountpoint -q /mnt/scratch 2>/dev/null || [[ -d /mnt/scratch ]]; then
    log "Scratch volume available at /mnt/scratch for dist/zips/backups"
    mkdir -p /mnt/scratch/dist 2>/dev/null || true
  fi

  # Verify volumes are ready
  log "Verifying disk layout..."
  df -h / /mnt/ccache /mnt/scratch 2>/dev/null || df -h /
  free -h
  if command -v ccache >/dev/null 2>&1; then
    ccache -s 2>/dev/null | head -5 || true
  fi
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  log "Starting build environment setup..."
  detect_os_and_install
  optimize_host
  log "Environment ready. Next steps:"
  echo "  - Open a new shell or add \"export PATH=\$HOME/bin:\$PATH\" to your shell rc"
  echo "  - Run: ./setup_xaga_env.sh to sync AxionOS source and device trees"
}

main "$@"
