# **AxionOS Manual Build Guide for POCO X4 GT / Redmi K50i / Redmi Note 11T Pro(+) (xaga)**

## Preparation

### Operating System
Make sure you have a GNU/Linux environment. **Debian** and **Ubuntu** are recommended.  
If you are using Arch Linux, you may encounter errors when building kernel. See the workaround section below.

### Hardware Requirements
You need a high performance computer:
- **RAM**: At least 16GB RAM is required for a smooth build
- **Storage**: ~300GB free disk space recommended
- **Swap**: Enable enough swap if you have limited RAM

**Reference build time**: AMD Ryzen 7 7700X + 16GB DDR5 RAM + NVMe SSD, with 8GB Zram and 64GB Swap. Around 3 hours for first full build without ccache.

---

## Working Directory Setup

Create and enter your working directory:

```bash
mkdir axionos
cd axionos
```

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
GPU_FREQS_PATH := /sys/devices/platform/13000000.mali/available_frequencies
GPU_MIN_FREQ_PATH := /sys/devices/platform/13000000.mali/hint_min_freq
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

1. **Out of memory during build**
   - Increase swap space
   - Reduce parallel jobs: `ax -br -j4`

2. **SELinux denials**
   - Add required SEPolicy rules to your device tree (see AxionOS README for details)

3. **Build fails with missing dependencies**
   - Run `repo sync` again to ensure all sources are up to date
   - Check if all device tree repositories are cloned correctly

---

## Credits

- **AxionOS Team** - ROM development
- **XagaForge** - Device trees and kernel sources
- **xiaomi-mediatek-devs** - MediaTek hardware support
- **Android Open Source Project (AOSP)** - Base Android
- **LineageOS** - Foundation and tools
