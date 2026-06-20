#!/bin/bash -e
# install_kodi.sh — Kodi 18 Leia + Arctic Zephyr 2 skin + YouTube + deps (ARMv6 / Pi 1).

echo "=== [install_kodi] Installing Kodi 18 (Leia) for ARMv6 ==="

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="pi"
TARGET_HOME="/home/${TARGET_USER}"
KODI_HOME="${TARGET_HOME}/.kodi"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=kodi_install_addon.sh
source "${SCRIPT_DIR}/kodi_install_addon.sh"

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
  unclutter \
  xmlstarlet

update-ca-certificates 2>/dev/null || true

install -d -o "${TARGET_USER}" -g "${TARGET_USER}" "${KODI_HOME}/userdata"
install -d -o "${TARGET_USER}" -g "${TARGET_USER}" "${KODI_HOME}/userdata/addon_data"

echo "=== [install_kodi] Installing Arctic Zephyr 2 skin and dependencies ==="
# script.module.pil is not published on the Leia mirror; omit it (PIL ships with Kodi Python).
AZ2_DEPS=(
  script.module.requests
  script.module.simplejson
  script.skinshortcuts
  script.image.resource.select
  plugin.program.autocompletion
  resource.images.studios.white
  resource.images.moviegenreicons.transparent
  resource.images.weathericons.outline-hd
)
for dep in "${AZ2_DEPS[@]}"; do
  kodi_install_addon "${dep}" || echo "WARNING: optional AZ2 dep ${dep} missing"
done

if ! kodi_install_addon "skin.arctic.zephyr.2"; then
  echo "=== [install_kodi] AZ2 mirror failed; cloning from GitHub ==="
  kodi_clone_skin_github "https://github.com/jurialmunkey/skin.arctic.zephyr.2.git" "skin.arctic.zephyr.2" \
    || echo "WARNING: Arctic Zephyr 2 unavailable; Estuary fallback will be used"
fi

SKIN_FALLBACK="${KODI_ADDON_DIR}/skin.estuary.modv2"
if [ ! -d "${SKIN_FALLBACK}" ]; then
  kodi_clone_skin_github "https://github.com/AnonTester/skin.estuary.modv2.git" "skin.estuary.modv2" \
    || echo "WARNING: Estuary MOD V2 fallback unavailable"
fi

echo "=== [install_kodi] Installing YouTube add-on and dependencies ==="
YT_DEPS=(
  script.module.six
  script.module.requests
  script.module.unidecode
  script.module.youtube.dl
  script.module.inputstreamhelper
)
for dep in "${YT_DEPS[@]}"; do
  kodi_install_addon "${dep}" || echo "WARNING: YouTube dep ${dep} missing"
done

YT_ZIP=$(kodi_mirror_index "http://mirrors.kodi.tv/addons/leia/plugin.video.youtube/" \
  | grep -oE 'plugin\.video\.youtube-6\.8\.[0-9][^"]*\.zip' \
  | grep -viE '\+matrix' | sort -V | tail -n1 || true)

if [ -n "${YT_ZIP}" ]; then
  kodi_install_addon "plugin.video.youtube" "${YT_ZIP}" \
    || kodi_install_youtube_github \
    || echo "WARNING: YouTube add-on could not be installed"
else
  kodi_install_addon "plugin.video.youtube" \
    || kodi_install_youtube_github \
    || echo "WARNING: YouTube add-on could not be installed"
fi

YT_VIDEO_INFO="${KODI_ADDON_DIR}/plugin.video.youtube/resources/lib/youtube_plugin/youtube/helper/video_info.py"
if [ -f "${YT_VIDEO_INFO}" ]; then
  sed -i "s/'clientVersion': '[^']*'/'clientVersion': '19.09.37'/g" "${YT_VIDEO_INFO}" 2>/dev/null || true
  sed -i "s/ANDROID_APP_VERSION = .*/ANDROID_APP_VERSION = '19.09.37'/" "${YT_VIDEO_INFO}" 2>/dev/null || true
fi

kodi_install_addon "plugin.video.themoviedb.helper" || true

if [ -x "${SCRIPT_DIR}/install_kodi_store.sh" ]; then
  "${SCRIPT_DIR}/install_kodi_store.sh"
fi

echo "=== [install_kodi] Applying pre-configured Kodi userdata ==="
cp /opt/smarttv-builder/config/kodi/guisettings.xml "${KODI_HOME}/userdata/guisettings.xml"
cp /opt/smarttv-builder/config/kodi/advancedsettings.xml "${KODI_HOME}/userdata/advancedsettings.xml"
cp /opt/smarttv-builder/config/kodi/sources.xml "${KODI_HOME}/userdata/sources.xml"
cp /opt/smarttv-builder/config/kodi/favourites.xml "${KODI_HOME}/userdata/favourites.xml"

chown -R "${TARGET_USER}:${TARGET_USER}" "${KODI_HOME}"
chmod -R a+rX "${KODI_ADDON_DIR}" 2>/dev/null || true

echo "=== [install_kodi] Done ==="
