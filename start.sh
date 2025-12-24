#!/usr/bin/env bash
# Bootstrap script: install bot requirements and run the automation
# Reads configuration from .env (or .env_xaga fallback) via config.py

set -euo pipefail

log()   { echo -e "[INFO]  $*"; }
warn()  { echo -e "[WARN]  $*" >&2; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not found. Please install it and re-run."
}

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$PROJECT_ROOT"

require_cmd python3

# Optional: create a local venv for Python deps
VENV_DIR=".venv"
PY="python3"

if command -v python3 >/dev/null 2>&1 && "$PY" -m venv --help >/dev/null 2>&1; then
  # Check if venv exists AND is valid (has activate script)
  if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    # Clean up broken venv if it exists
    if [[ -d "$VENV_DIR" ]]; then
      log "Removing broken virtual environment at $VENV_DIR"
      rm -rf "$VENV_DIR"
    fi
    log "Creating Python virtual environment at $VENV_DIR"
    "$PY" -m venv "$VENV_DIR"
  fi
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  PY="python"
fi

log "Upgrading pip..."
"$PY" -m pip install --upgrade pip >/dev/null

log "Installing Python dependencies (requests, python-dotenv, pillow)..."
"$PY" -m pip install --upgrade requests python-dotenv pillow >/dev/null

# Ensure helper scripts are executable if present
for f in setup_build_env.sh setup_xaga_env.sh; do
  if [[ -f "$f" ]]; then
    chmod +x "$f" || true
  fi
done

# Pick env file: prefer provided ENV_FILE, else .env, else .env_xaga
ENV_FILE_PATH=${ENV_FILE:-}
if [[ -z "${ENV_FILE_PATH}" ]]; then
  if [[ -f .env ]]; then
    ENV_FILE_PATH=".env"
  elif [[ -f .env_xaga ]]; then
    ENV_FILE_PATH=".env_xaga"
    warn "Using .env_xaga template. Consider copying it to .env and editing your secrets."
  else
    warn "No .env or .env_xaga found. Bot will run with built-in defaults."
    ENV_FILE_PATH=""
  fi
fi

if [[ -n "${ENV_FILE_PATH}" ]]; then
  export ENV_FILE="$ENV_FILE_PATH"
  log "Using configuration from: $ENV_FILE"
fi

log "Starting bot..."
exec "$PY" bot.py --env-file "${ENV_FILE:-}" "$@"
