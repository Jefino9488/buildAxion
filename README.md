# **AxionOS Manual Build Guide for POCO X4 GT / Redmi K50i / Redmi Note 11T Pro(+) (xaga)**

## Preparation

### Operating System

Make sure you have a GNU/Linux environment. **Debian** and **Ubuntu** are recommended.  
If you are using Arch Linux, you may encounter errors when building kernel. See the workaround section below.

### Hardware Requirements

You need a high performance computer:

- **RAM**: At least 16GB RAM is required for a smooth build
- **Storage**: ~300GB free disk space recommended
- **Swap**: 64GB swap is highly recommended for 16GB RAM systems (automated by `setup_build_env.sh` with swappiness=10)
- **Cache**: 100GB ccache recommended (automated by `setup_build_env.sh`, persisted in `~/.bashrc`)
- **Storage Layout**: For cloud servers with extra volumes, mounting to `/build` is recommended to avoid disk contention (automated by `setup_build_env.sh` if `BUILD_VOLUME_DEVICE` is set)
- **OOM Prevention**: Safe build flags are automatically applied by the CI bot to prevent Out-Of-Memory errors during compilation.

**Reference build time**: AMD Ryzen 7 7700X + 16GB DDR5 RAM + NVMe SSD, with 8GB Zram and 64GB Swap. Around 3 hours for first full build without ccache.

---

##  Build System

This project uses proper AOSP patterns for maintainable, reproducible builds:

### Directory Structure

```
buildAxion/
├── local_manifests/              # XML manifests for repo
│   ├── xaga.xml                  # Device/kernel/vendor repos
│   └── miui_camera.xml           # Optional MIUI camera
├── patches/                      # Version-controlled patches
│   └── external_wpa_supplicant_8/
├── apply_patches.sh              # Intelligent patch application
├── generate_wpa_patches.sh       # Generate patches from commits
└── setup_xaga_env.sh             # Uses local manifests
```

### Forked Repos

These repos point to your GitHub forks:

| Path | Remote |
|------|--------|
| `device/xiaomi/xaga` | Jefino9488/android_device_xiaomi_xaga |
| `device/xiaomi/mt6895-common` | Jefino9488/android_device_xiaomi_mt6895-common |
| `device/mediatek/sepolicy_vndr` | Jefino9488/android_device_mediatek_sepolicy_vndr |

### How It Works

1. **`repo init`** - Initialize with AxionAOSP manifest
2. **Local manifests copied** - `local_manifests/` → `.repo/local_manifests/`
3. **`repo sync`** - Fetches base + all device trees automatically
4. **Patches applied** - `apply_patches.sh` applies version-controlled patches

### Making Changes to Forks

```bash
cd ~/axionos/device/xiaomi/xaga
# Edit files...
git add . && git commit -m "Your change"
git push origin HEAD:lineage-23.1  # Pushes to YOUR fork!
```

---

## Automated Build Guide (Recommended)

This project includes a fully automated build automation suite that handles environment setup, source syncing, and compilation with built-in OOM (Out-of-Memory) prevention, storage optimization, and Telegram notifications.

### 1. Initial Setup

Clone this repository to your build server:

```bash
git clone https://github.com/your-username/buildAxion.git
cd buildAxion
```

### 2. Configuration

Copy the template environment file and edit it with your settings:

```bash
cp .env_xaga .env
nano .env
```

**Key Configuration Options:**

- `RUN_ENV_SETUP=true`: Automatically installs all dependencies, configures **64GB swap**, **100GB ccache**, and tunes **swappiness=10**.
- `RUN_SOURCE_SYNC=true`: Automatically initializes the repo and syncs all AxionOS and xaga-specific trees.
- `RUN_BUILD=true`: Starts the ROM compilation immediately after setup/sync.
- `CONFIG_BOT_TOKEN` & `CONFIG_CHATID`: Enter your Telegram bot details to receive real-time build progress and banners.
- `PIXELDRAIN_API_KEY`: Enter your key to automatically upload the finished build to Pixeldrain.
- `BUILD_VOLUME_DEVICE`: (Optional) If you have an extra NVMe volume (e.g., `/dev/sdb`), set this to format and mount it to `/build` automatically.

#### `.env` Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_ENV_SETUP` | `true` | Install packages, setup swap (64G) and ccache (100G). |
| `RUN_SOURCE_SYNC`| `true` | Sync AxionOS and xaga-specific source trees. |
| `RUN_BUILD` | `false` | Start the ROM build after sync. |
| `WORKDIR` | `axionos`| Directory where sources will be synced. |
| `DEVICE` | `xaga` | Target device codename. |
| `ROM_TYPE` | `axion-pico`| `axion-pico`, `axion-core`, or `axion-vanilla`. |
| `USE_SAFE_BUILD` | `true` | Apply OOM-prevention flags (`-Wl,--no-keep-memory`). |
| `THREADS` | (Auto) | Number of CPU threads to use for build. |
| `CONFIG_BOT_TOKEN`| - | Telegram Bot API Token. |
| `CONFIG_CHATID` | - | Telegram Chat/Channel ID for notifications. |
| `PIXELDRAIN_API_KEY`| - | API key for automated Pixeldrain uploads. |
| `RCLONE_REMOTE` | - | Rclone remote name for uploads. |
| `POWEROFF` | `false` | Shutdown the server after build success/fail. |

### 3. Launch the Automation

Simply run the bootstrap script. It will handle Python dependencies, virtual environment setup, and start the CI bot:

```bash
chmod +x start.sh
./start.sh
```

### What the Automation Does for You

- ✅ **Host Optimization**: Sets up a massive 64GB swap file and 100GB ccache to ensure stability on 16GB RAM machines.

- ✅ **Storage Management**: Moves `out/` and `ccache/` to the high-speed `/build` volume if detected.
- ✅ **OOM Prevention**: Automatically injects `-Wl,--no-keep-memory` and load-aware scheduling (`-l8`) into the build process.
- ✅ **Smart Syncing**: Uses optimized thread counts (4x CPU count) for faster source downloads.
- ✅ **Notifications**: Generates a custom build banner and sends progress updates to Telegram.
- ✅ **Auto-Upload**: Falls back through Rclone -> Pixeldrain -> Gofile to ensure your build is uploaded safely.

---

## Manual Build Guide (Legacy)

If you prefer to run steps manually, follow the sections below.

Create and enter your working directory:

```bash
mkdir axionos
cd axionos
```

---

## Build Status Script (Optional)

Use this script to get build status notifications via Telegram during your manual builds.

### Download the Script

```bash
wget https://raw.githubusercontent.com/Saikrishna1504/build-script/main/ci_bot.py
chmod +x ci_bot.py
```

### Configure Variables

Edit the script and update the configuration:

```bash
nano ci_bot.py
```

**Key variables to set:**

```python
DEVICE = "xaga"                    # Your device codename
VARIANT = "userdebug"              # Build variant: user/userdebug/eng
ROM_TYPE = "axion-pico"            # Options: "axion-pico" / "axion-core" / "axion-vanilla"
CONFIG_OFFICIAL_FLAG = ""          # Set to "1" for official builds
CONFIG_CHATID = "-xxxxxxxx"        # Your Telegram group/channel chat ID
CONFIG_BOT_TOKEN = ""              # Your Telegram bot token (from BotFather)
CONFIG_ERROR_CHATID = ""           # Secondary chat for error logs
RCLONE_REMOTE = ""                 # Your rclone remote for uploading
RCLONE_FOLDER = ""                 # Your rclone folder name
PIXELDRAIN_API_KEY = ""            # Your Pixeldrain API key for uploading
BUILD_VOLUME_DEVICE = ""           # Optional: extra volume device (e.g., "/dev/sdb")
USE_SAFE_BUILD = True              # Enable OOM-safe flags (default: True)
POWEROFF = False                   # Turn off server after build
```

### Requirements

```bash
# Python packages (Debian/Ubuntu)
sudo apt install python3-requests python3-pil

# Python packages (Arch Linux)
sudo pacman -S python-requests python-pillow

# Optional: rclone for cloud uploads
sudo apt install rclone git

# Required for OTA JSON upload
sudo apt install netcat-openbsd
```

### Usage

```bash
python3 ci_bot.py -h
```

For more details, visit: [Saikrishna1504/build-script](https://github.com/Saikrishna1504/build-script)

---

## Fetching Source Code

### Initialize AxionOS Repository

```bash
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.0 --git-lfs
```

### Sync the Source

```bash
repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j$(nproc --all)
```

---

## Device Trees & Dependencies

Clone all required repositories for the xaga device:

### Device Trees

```bash
git clone https://github.com/XagaForge/android_device_xiaomi_xaga device/xiaomi/xaga
git clone https://github.com/XagaForge/android_device_xiaomi_mt6895-common device/xiaomi/mt6895-common
```

### Kernel Sources

```bash
git clone https://github.com/XagaForge/android_kernel_xiaomi_mt6895 kernel/xiaomi/mt6895
```

### Vendor Trees

```bash
git clone https://gitlab.com/priiii08918/android_vendor_xiaomi_xaga vendor/xiaomi/xaga
git clone https://github.com/XagaForge/android_vendor_xiaomi_mt6895-common vendor/xiaomi/mt6895-common
git clone https://github.com/XagaForge/android_vendor_firmware vendor/firmware
```

### Hardware Dependencies

```bash
git clone https://github.com/XagaForge/android_hardware_xiaomi hardware/xiaomi
git clone https://github.com/XagaForge/android_hardware_mediatek hardware/mediatek
```

### MediaTek Dependencies

```bash
git clone https://github.com/XagaForge/android_device_mediatek_sepolicy_vndr device/mediatek/sepolicy_vndr
git clone https://github.com/XagaForge/android_vendor_mediatek_ims vendor/mediatek/ims
```

### MIUI Camera (Optional)

```bash
git clone https://gitlab.com/priiii1808/proprietary_vendor_xiaomi_miuicamera-xaga.git vendor/xiaomi/miuicamera-xaga
```

---

## Required Patches

Apply these patches to `external/wpa_supplicant_8`:

1. **MediaTek changes for wpa_supplicant_8**  
   [View Patch](https://github.com/Nothing-2A/android_external_wpa_supplicant_8/commit/39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048)

2. **Enable WAPI for wpa_supplicant_8**  
   [View Patch](https://github.com/Nothing-2A/android_external_wpa_supplicant_8/commit/37a6e255d9d68fb483d12db550028749b280509b)

To apply patches manually:

```bash
cd external/wpa_supplicant_8
git fetch https://github.com/Nothing-2A/android_external_wpa_supplicant_8
git cherry-pick 39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048
git cherry-pick 37a6e255d9d68fb483d12db550028749b280509b
cd ../..
```

---

## Device Tree Configuration for AxionOS

Ensure your device makefile includes the following AxionOS-specific configurations:

### Required Makefile Additions

Add to your device makefile (e.g., `device/xiaomi/xaga/axion_xaga.mk`):

```make
TARGET_DISABLE_EPPE := true
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)
```

### AxionOS Device Properties

```make
# Camera information
AXION_CAMERA_REAR_INFO := 64,8,2
AXION_CAMERA_FRONT_INFO := 16

# Maintainer name (underscores become spaces)
AXION_MAINTAINER := Your_Name

# Processor name (underscores become spaces)
AXION_PROCESSOR := Dimensity_8100
```

### Optional Features

```make
# Enable blur effects
TARGET_ENABLE_BLUR := true

# Enable ViPER4AndroidFX (requires proper drivers)
TARGET_INCLUDE_VIPERFX := true

# Include LineageOS prebuilt apps
TARGET_INCLUDES_LOS_PREBUILTS := false
```

### Performance Tuning (Optional)

```make
# CPU governor support
PERF_GOV_SUPPORTED := true
PERF_DEFAULT_GOV := schedutil

# GPU paths (MediaTek Dimensity 8100)
GPU_FREQS_PATH := /sys/class/devfreq/13000000.mali/available_frequencies
GPU_MIN_FREQ_PATH := /sys/class/devfreq/13000000.mali/min_freq
```

### Audio Configuration

> **Note**: You may need to modify `config/audio/audio_effects.xml` in your device tree for proper audio effects support.

---

## Fix for Arch Linux Users

When building Android kernel on Arch Linux, `libyaml` cannot be found and configured correctly. Apply this workaround:

```bash
cp -r /usr/include/yaml.h prebuilts/kernel-build-tools/linux-x86/include/yaml.h
cp -r /lib64/libyaml-0.so.2.0.9 prebuilts/kernel-build-tools/linux-x86/lib64/libyaml.so
```

---

## Building AxionOS

### Step 1: Set Up Build Environment

```bash
. build/envsetup.sh
export USE_CCACHE=1
```

### Step 2: Generate Private Keys (First Build Only)

```bash
gk -s
```

### Step 3: Choose Device and Variant

```bash
axion xaga [variant]
```

**Available variants:**

- `gms core` → Core Google Mobile Services (default)
- `gms pico` → Minimal Google apps
- `va` → Vanilla (no GMS)

**Examples:**

```bash
axion xaga              # Default: gms core
axion xaga gms pico     # Minimal Google apps
axion xaga va           # Vanilla build
```

### Step 4: Build the ROM

```bash
ax -br -j$(nproc --all)
```

Or specify thread count manually:

```bash
ax -br -j16
```

---

## Syncing Updates

After the first sync, use this command to update your source:

```bash
axionSync
```

---

## Testing Before Flashing (DSU Method)

You can test your build using DSU (Dynamic System Updates) before flashing:

1. Select `odm`, `product`, `system`, `system_ext`, `vendor`, `product` images
2. Compress them into a ZIP file (use "Store" compression, no compression)
3. Push to your device
4. Install with DSU Sideloader
5. Reboot and test

If it works well, flash it permanently to your device!

---

## Troubleshooting

### Common Issues

### 1. Out of memory during build

- **Recommended**: Use the [Automated Build Guide](#-automated-build-guide-recommended) which automatically sets up 64GB swap and applies OOM-prevention flags (`USE_SAFE_BUILD=true`).
- Increase swap space manually (64GB recommended for 16GB RAM).
- Reduce parallel jobs: `ax -br -j4`
- Use safe linker flags: `export LDFLAGS="$LDFLAGS -Wl,--no-keep-memory"`

1. **SELinux denials**
   - Add required SEPolicy rules to your device tree (see AxionOS README for details)

2. **Build fails with missing dependencies**
   - Run `repo sync` again to ensure all sources are up to date
   - Check if all device tree repositories are cloned correctly

---

## Credits

- **AxionOS Team** - ROM development
- **XagaForge** - Device trees and kernel sources
- **xiaomi-mediatek-devs** - MediaTek hardware support
- **Android Open Source Project (AOSP)** - Base Android
- **LineageOS** - Foundation and tools
