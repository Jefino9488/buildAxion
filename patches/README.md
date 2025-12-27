# Patches Directory

This directory contains `.patch` files organized by target repository path.

## Structure

```
patches/
├── external_wpa_supplicant_8/      # Patches for external/wpa_supplicant_8
│   ├── 0001-mtk-wpa-changes.patch
│   └── 0002-enable-wapi.patch
├── frameworks_base/                 # Example: patches for frameworks/base
│   └── 0001-some-fix.patch
└── README.md
```

## Naming Convention

Patches are named with a numeric prefix to ensure correct application order:

- `0001-*` applies first
- `0002-*` applies second
- etc.

## How to Create a Patch

### From a commit

```bash
cd external/wpa_supplicant_8
git format-patch -1 <commit-sha> -o ~/buildAxion/patches/external_wpa_supplicant_8/
```

### From uncommitted changes

```bash
git diff > ~/buildAxion/patches/repo_path/0001-my-change.patch
```

### From a remote commit

```bash
git fetch https://github.com/Someone/some-repo
git format-patch -1 <remote-commit-sha> -o ~/buildAxion/patches/target_repo/
```

## Applying Patches

Use the `apply_patches.sh` script in the project root:

```bash
# Apply all patches to a synced source tree
./apply_patches.sh ~/axionos

# Reverse (unapply) all patches
./apply_patches.sh ~/axionos --reverse

# Dry-run to check what would be applied
./apply_patches.sh ~/axionos --dry-run
```

## Tips

1. **Always test patches** after sync to ensure they apply cleanly
2. **Keep patches minimal** - only include necessary changes
3. **Update patches** when upstream changes cause conflicts
4. **Consider forking** repos you patch frequently
