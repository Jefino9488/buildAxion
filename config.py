#!/usr/bin/env python3
"""
Configuration loader for the build automation bot.

Reads a .env file (dotenv format) and exposes strongly-typed settings
for the automation flow, including environment setup, source sync, and
future build/notify options.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, asdict
from typing import Any, Dict, Optional

try:
    from dotenv import dotenv_values
except Exception:  # pragma: no cover - optional dependency installed by start.sh
    dotenv_values = None  # type: ignore


def _to_bool(val: Optional[str], default: bool = False) -> bool:
    if val is None:
        return default
    s = str(val).strip().lower()
    if s in {"1", "true", "yes", "y", "on"}:
        return True
    if s in {"0", "false", "no", "n", "off"}:
        return False
    return default


def _to_int(val: Optional[str], default: int) -> int:
    try:
        return int(str(val).strip()) if val is not None else default
    except Exception:
        return default


@dataclass
class BotConfig:
    # Flow control
    RUN_ENV_SETUP: bool = True
    RUN_SOURCE_SYNC: bool = True
    RUN_BUILD: bool = False
    DRY_RUN: bool = False

    # AxionOS/AOSP repo settings
    AXION_REMOTE_URL: str = "https://github.com/AxionAOSP/android.git"
    AXION_BRANCH: str = "lineage-23.0"

    # Sync/device related
    WORKDIR: str = "axionos"
    THREADS: int = os.cpu_count() or 8
    WITH_MIUI_CAM: bool = False
    APPLY_WPA_PATCHES: bool = False
    BUILD_VOLUME_DEVICE: str = ""
    USE_SAFE_BUILD: bool = True

    # Build/bot options (reserved for future use / parity with README ci bot)
    DEVICE: str = "xaga"
    VARIANT: str = "userdebug"
    ROM_TYPE: str = "axion-pico"  # axion-pico | axion-core | axion-vanilla
    CONFIG_OFFICIAL_FLAG: str = ""  # "1" for official
    CONFIG_CHATID: str = ""         # Telegram chat id
    CONFIG_BOT_TOKEN: str = ""      # Telegram bot token
    CONFIG_ERROR_CHATID: str = ""   # Optional error log chat id
    RCLONE_REMOTE: str = ""
    RCLONE_FOLDER: str = ""
    PIXELDRAIN_API_KEY: str = ""
    POWEROFF: bool = False

    # Telegram/announce options
    UPLOAD_OTA_JSON: bool = True
    OTA_JSON_PATH: str = "vendor/ota/your_device_name.json"
    PIN_SUCCESS_MESSAGE: bool = True

    # Internal
    ENV_FILE: str = ".env"

    @classmethod
    def load(cls, env_file: Optional[str] = None) -> "BotConfig":
        # Load from dotenv file if python-dotenv is available; otherwise rely on os.environ
        merged: Dict[str, str] = {}
        env_path = env_file or os.environ.get("ENV_FILE") or ".env"

        # Fallback to .env_xaga if .env is missing
        if not os.path.isfile(env_path) and os.path.isfile(".env_xaga"):
            env_path = ".env_xaga"

        if dotenv_values is not None and os.path.isfile(env_path):
            try:
                file_vals = dotenv_values(env_path)  # type: ignore
                merged.update({k: v for k, v in file_vals.items() if v is not None})
            except Exception:
                # Ignore parse errors, continue with environment
                pass

        # Overlay actual environment variables (highest priority)
        for k, v in os.environ.items():
            merged[k] = v

        cfg = cls(
            RUN_ENV_SETUP=_to_bool(merged.get("RUN_ENV_SETUP"), True),
            RUN_SOURCE_SYNC=_to_bool(merged.get("RUN_SOURCE_SYNC"), True),
            RUN_BUILD=_to_bool(merged.get("RUN_BUILD"), False),
            DRY_RUN=_to_bool(merged.get("DRY_RUN"), False),
            AXION_REMOTE_URL=merged.get("AXION_REMOTE_URL", cls.AXION_REMOTE_URL),
            AXION_BRANCH=merged.get("AXION_BRANCH", cls.AXION_BRANCH),
            WORKDIR=merged.get("WORKDIR", cls.WORKDIR),
            THREADS=_to_int(merged.get("THREADS"), cls.THREADS),
            WITH_MIUI_CAM=_to_bool(merged.get("WITH_MIUI_CAM"), False),
            APPLY_WPA_PATCHES=_to_bool(merged.get("APPLY_WPA_PATCHES"), False),
            BUILD_VOLUME_DEVICE=merged.get("BUILD_VOLUME_DEVICE", cls.BUILD_VOLUME_DEVICE),
            USE_SAFE_BUILD=_to_bool(merged.get("USE_SAFE_BUILD"), True),
            DEVICE=merged.get("DEVICE", cls.DEVICE),
            VARIANT=merged.get("VARIANT", cls.VARIANT),
            ROM_TYPE=merged.get("ROM_TYPE", cls.ROM_TYPE),
            CONFIG_OFFICIAL_FLAG=merged.get("CONFIG_OFFICIAL_FLAG", cls.CONFIG_OFFICIAL_FLAG),
            CONFIG_CHATID=merged.get("CONFIG_CHATID", cls.CONFIG_CHATID),
            CONFIG_BOT_TOKEN=merged.get("CONFIG_BOT_TOKEN", cls.CONFIG_BOT_TOKEN),
            CONFIG_ERROR_CHATID=merged.get("CONFIG_ERROR_CHATID", cls.CONFIG_ERROR_CHATID),
            RCLONE_REMOTE=merged.get("RCLONE_REMOTE", cls.RCLONE_REMOTE),
            RCLONE_FOLDER=merged.get("RCLONE_FOLDER", cls.RCLONE_FOLDER),
            PIXELDRAIN_API_KEY=merged.get("PIXELDRAIN_API_KEY", cls.PIXELDRAIN_API_KEY),
            POWEROFF=_to_bool(merged.get("POWEROFF"), False),
            UPLOAD_OTA_JSON=_to_bool(merged.get("UPLOAD_OTA_JSON"), True),
            OTA_JSON_PATH=merged.get("OTA_JSON_PATH", cls.OTA_JSON_PATH),
            PIN_SUCCESS_MESSAGE=_to_bool(merged.get("PIN_SUCCESS_MESSAGE"), True),
            ENV_FILE=env_path,
        )
        return cfg

    def to_script_env(self) -> Dict[str, str]:
        """Environment variables to pass into setup_xaga_env.sh."""
        return {
            "AXION_REMOTE_URL": self.AXION_REMOTE_URL,
            "AXION_BRANCH": self.AXION_BRANCH,
            "WORKDIR": self.WORKDIR,
            "THREADS": str(self.THREADS),
            "WITH_MIUI_CAM": "true" if self.WITH_MIUI_CAM else "false",
            "APPLY_WPA_PATCHES": "true" if self.APPLY_WPA_PATCHES else "false",
            "BUILD_VOLUME_DEVICE": self.BUILD_VOLUME_DEVICE,
        }

    def as_dict(self) -> Dict[str, Any]:
        return asdict(self)


__all__ = ["BotConfig"]
