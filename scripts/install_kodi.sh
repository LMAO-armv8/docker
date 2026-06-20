#!/bin/bash -e
# install_kodi.sh
# Runs inside the pi-gen chroot (target = Raspberry Pi 1 Model B/B+, ARMv6).
#
# Installs Kodi and bakes in the Estuary MOD V2 skin and the YouTube addon.
#
# IMPORTANT: Pi 1 / Pi Zero (ARMv6) only ever got official Kodi packages up
# to Kodi 18 "Leia". Kodi 19+ dropped ARMv6 binaries entirely, so "latest
# version compatible with ARMv6" is Kodi 18.x. This script intentionally
# does not try to fetch a newer Kodi - that build does not exist for this
# hardware. See README.md "Limitations" for details.

echo "=== [install_kodi] Installing Kodi 18 (Leia) for ARMv6 ==="

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="pi"
TARGET_HOME="/home/${TARGET_USER}"
KODI_HOME="${TARGET_HOME}/.kodi"

# The archive.raspberrypi.org repo (which ships the ARMv6/ARMv7/ARMv8
# multi-arch Kodi build, auto-selected at runtime) is already part of the
# default Raspberry Pi OS Buster apt sources pi-gen bootstraps from, so we
# don't need to add anything extra here - just make sure the index is fresh.
apt-get update

apt-get install -y --no-install-recommends \
  kodi \
  kodi-bin \
  kodi-eventclients-kodi-send \
  kodi-inputstream-adaptive \
  kodi-peripheral-joystick \
  kodi-pvr-iptvsimple \
  kodi-visualization-spectrum \
  git \
  unzip \
  curl \
  ca-certificates \
  unclutter

# --- User data layout -------------------------------------------------
install -d -o "${TARGET_USER}" -g "${TARGET_USER}" "${KODI_HOME}"
install -d -o "${TARGET_USER}" -g "${TARGET_USER}" "${KODI_HOME}/userdata"
install -d -o "${TARGET_USER}" -g "${TARGET_USER}" "${KODI_HOME}/addons"
install -d -o "${TARGET_USER}" -g "${TARGET_USER}" "${KODI_HOME}/userdata/addon_data"

# --- Estuary MOD V2 skin ------------------------------------------------
# Guilouz's Estuary MOD V2 for Kodi 18 (the same major version line is what
# all the mirrors of this skin trace back to). We pull it straight from
# source rather than hardcoding a zip URL, since GitHub repos are far more
# stable links than third-party addon mirrors.
echo "=== [install_kodi] Installing Estuary MOD V2 skin ==="
SKIN_DIR="${KODI_HOME}/addons/skin.estuary.modv2"
if [ ! -d "${SKIN_DIR}" ]; then
  git clone --depth 1 https://github.com/AnonTester/skin.estuary.modv2.git "${SKIN_DIR}" \
    || echo "WARNING: could not fetch Estuary MOD V2 (network issue during build?). Kodi will fall back to the stock Estuary skin until you install it manually."
fi

# --- YouTube addon -------------------------------------------------------
# Installed from Kodi's own official mirror (mirrors.kodi.tv), which hosts
# the exact zip layout Kodi's "install from zip" expects. We resolve the
# latest available Leia-compatible build dynamically instead of pinning a
# version number that will eventually go stale.
echo "=== [install_kodi] Installing YouTube addon ==="
YT_DIR="${KODI_HOME}/addons/plugin.video.youtube"
YT_INDEX_URL="http://mirrors.kodi.tv/addons/leia/plugin.video.youtube/"
YT_ZIP_NAME=$(curl -fsSL "${YT_INDEX_URL}" 2>/dev/null \
  | grep -oE 'plugin\.video\.youtube-[0-9][^"]*\.zip' \
  | sort -V | tail -n1 || true)

if [ -n "${YT_ZIP_NAME}" ]; then
  curl -fsSL -o "/tmp/${YT_ZIP_NAME}" "${YT_INDEX_URL}${YT_ZIP_NAME}"
  TMP_EXTRACT="/tmp/yt-extract"
  rm -rf "${TMP_EXTRACT}"
  mkdir -p "${TMP_EXTRACT}"
  unzip -q "/tmp/${YT_ZIP_NAME}" -d "${TMP_EXTRACT}"
  rm -rf "${YT_DIR}"
  mv "${TMP_EXTRACT}/plugin.video.youtube" "${YT_DIR}"
  rm -rf "${TMP_EXTRACT}" "/tmp/${YT_ZIP_NAME}"
else
  echo "WARNING: could not resolve a YouTube addon zip from ${YT_INDEX_URL}. Install it manually from Kodi's add-on browser on first boot."
fi

# Kodi's built-in official repository (repository.xbmc.org) is enabled by
# default and will automatically resolve/download the YouTube addon's
# Python module dependencies (script.module.requests, etc.) the first time
# Kodi starts with an internet connection - no need to bundle those here.

# --- Pre-configured userdata ---------------------------------------------
# These files (guisettings.xml with the skin already active, sources.xml,
# advancedsettings.xml, favourites.xml with the "Launch RetroArch /
# EmulationStation" shortcut) are supplied by this repo under config/kodi/.
echo "=== [install_kodi] Applying pre-configured Kodi userdata ==="
cp /opt/smarttv-builder/config/kodi/guisettings.xml "${KODI_HOME}/userdata/guisettings.xml"
cp /opt/smarttv-builder/config/kodi/advancedsettings.xml "${KODI_HOME}/userdata/advancedsettings.xml"
cp /opt/smarttv-builder/config/kodi/sources.xml "${KODI_HOME}/userdata/sources.xml"
cp /opt/smarttv-builder/config/kodi/favourites.xml "${KODI_HOME}/userdata/favourites.xml"

chown -R "${TARGET_USER}:${TARGET_USER}" "${KODI_HOME}"

echo "=== [install_kodi] Done ==="
