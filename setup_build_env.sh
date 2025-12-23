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
    warn "Add $HOME/bin to your PATH, e.g.: echo 'export PATH=\"$HOME/bin:$PATH\"' >> ~/.bashrc && source ~/.bashrc"
  fi
}

install_debian_based() {
  need_cmd sudo
  log "Updating apt package index..."
  sudo apt-get update -y
  log "Installing base build dependencies (Debian/Ubuntu)..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git git-lfs curl wget ca-certificates gnupg \
    openjdk-17-jdk \
    build-essential bc bison flex gperf zip unzip \
    ccache lzop schedtool \
    python3 python3-pip \
    zlib1g-dev libncurses5 libncurses5-dev libtinfo5 \
    libssl-dev libxml2-utils xsltproc \
    rsync coreutils file make cmake ninja-build pkg-config \
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

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  log "Starting build environment setup..."
  detect_os_and_install
  log "Environment ready. Next steps:"
  echo "  - Open a new shell or add \"export PATH=\$HOME/bin:\$PATH\" to your shell rc"
  echo "  - Run: ./setup_xaga_env.sh to sync AxionOS source and device trees"
}

main "$@"
