#!/usr/bin/env bash
# Purpose: Apply or reverse patches to a synced AOSP source tree
# Patches are organized in patches/<repo_path>/ directories
#
# Usage:
#   ./apply_patches.sh <source_dir>              # Apply all patches
#   ./apply_patches.sh <source_dir> --reverse    # Reverse all patches
#   ./apply_patches.sh <source_dir> --dry-run    # Check without applying

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PATCHES_DIR="${SCRIPT_DIR}/patches"

log()   { echo -e "\033[1;32m[PATCH]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <source_dir> [--reverse|--dry-run]

Arguments:
  source_dir    Path to the AOSP source tree (e.g., ~/axionos)
  --reverse     Reverse (unapply) all patches
  --dry-run     Show what would be done without applying

Examples:
  $(basename "$0") ~/axionos
  $(basename "$0") ~/axionos --reverse
  $(basename "$0") ~/axionos --dry-run
EOF
  exit 1
}

apply_patches_for_repo() {
  local source_dir="$1"
  local patch_subdir="$2"
  local reverse="${3:-false}"
  local dry_run="${4:-false}"
  
  # Convert patch subdir to repo path (underscores -> slashes)
  local repo_path="${patch_subdir//_//}"
  local target_dir="${source_dir}/${repo_path}"
  local patch_dir="${PATCHES_DIR}/${patch_subdir}"
  
  if [[ ! -d "$target_dir" ]]; then
    warn "Target repo not found: $target_dir (skipping)"
    return 0
  fi
  
  # Find all .patch files sorted by name
  local patches=()
  while IFS= read -r -d '' f; do
    patches+=("$f")
  done < <(find "$patch_dir" -maxdepth 1 -name "*.patch" -print0 | sort -z)
  
  if [[ ${#patches[@]} -eq 0 ]]; then
    return 0
  fi
  
  log "Processing ${#patches[@]} patch(es) for $repo_path"
  
  pushd "$target_dir" > /dev/null
  
  for patch_file in "${patches[@]}"; do
    local patch_name=$(basename "$patch_file")
    
    # Check if patch is already applied (for forward apply)
    local patch_id=""
    if [[ "$patch_name" =~ ^[0-9]+-(.*)\.patch$ ]]; then
      patch_id="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$reverse" == "true" ]]; then
      if [[ "$dry_run" == "true" ]]; then
        log "  [DRY-RUN] Would reverse: $patch_name"
      else
        log "  Reversing: $patch_name"
        if git apply --reverse --check "$patch_file" 2>/dev/null; then
          git apply --reverse "$patch_file"
          log "    ✓ Reversed successfully"
        else
          warn "    ✗ Patch not applied or conflicts (skipped)"
        fi
      fi
    else
      # Check if already applied
      if git apply --check "$patch_file" 2>/dev/null; then
        if [[ "$dry_run" == "true" ]]; then
          log "  [DRY-RUN] Would apply: $patch_name"
        else
          log "  Applying: $patch_name"
          git apply "$patch_file"
          git add -A
          git commit -m "Applied patch: $patch_name" --no-verify 2>/dev/null || true
          log "    ✓ Applied and committed"
        fi
      else
        # Check if it's already applied (reverse would succeed)
        if git apply --reverse --check "$patch_file" 2>/dev/null; then
          log "  Already applied: $patch_name (skipping)"
        else
          warn "  ✗ Conflict or invalid patch: $patch_name"
          warn "    You may need to update this patch for the current source version"
        fi
      fi
    fi
  done
  
  popd > /dev/null
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
  fi
  
  local source_dir="$1"
  local reverse="false"
  local dry_run="false"
  
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reverse) reverse="true" ;;
      --dry-run) dry_run="true" ;;
      -h|--help) usage ;;
      *) error "Unknown option: $1" ;;
    esac
    shift
  done
  
  # Validate source directory
  if [[ ! -d "$source_dir/.repo" ]]; then
    error "Not a valid AOSP source: $source_dir (missing .repo directory)"
  fi
  
  # Validate patches directory
  if [[ ! -d "$PATCHES_DIR" ]]; then
    warn "No patches directory found: $PATCHES_DIR"
    exit 0
  fi
  
  log "Source: $source_dir"
  log "Patches: $PATCHES_DIR"
  [[ "$reverse" == "true" ]] && log "Mode: REVERSE"
  [[ "$dry_run" == "true" ]] && log "Mode: DRY-RUN"
  echo ""
  
  # Find all patch subdirectories
  local total_applied=0
  for patch_subdir in "$PATCHES_DIR"/*/; do
    [[ ! -d "$patch_subdir" ]] && continue
    local subdir_name=$(basename "$patch_subdir")
    [[ "$subdir_name" == "README.md" ]] && continue
    
    apply_patches_for_repo "$source_dir" "$subdir_name" "$reverse" "$dry_run"
  done
  
  echo ""
  log "Done!"
}

main "$@"
