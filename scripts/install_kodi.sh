#!/bin/bash -e
# install_kodi.sh — Kodi 18 Leia + Arctic Zephyr 2 skin + YouTube + deps (ARMv6 / Pi 1).

echo "=== [install_kodi] Installing Kodi 18 (Leia) for ARMv6 ==="

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="pi"
TARGET_HOME="/home/${TARGET_USER}"
KODI_HOME="${TARGET_HOME}/.kodi"
KODI_USER_ADDONS="${KODI_HOME}/addons"
KODI_PACKAGES="/usr/local/share/smarttv/addon-packages"
KODI_CONFIG_DST="/usr/local/share/smarttv/kodi-config"
KODI_STORE_SRC="/usr/local/share/smarttv/plugin.program.smarttvstore"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export KODI_ADDON_DIR="/usr/share/kodi/addons"
export KODI_USER_ADDON_DIR="${KODI_USER_ADDONS}"
export KODI_SAVE_PACKAGES_DIR="${KODI_PACKAGES}"

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

install -d -o "${TARGET_USER}" -g "${TARGET_USER}" \
  "${KODI_HOME}/userdata" "${KODI_HOME}/userdata/addon_data" "${KODI_USER_ADDONS}" \
  "${KODI_PACKAGES}" "${KODI_CONFIG_DST}"

kodi_require_addon() {
  local addon_id="$1"
  if [ -d "${KODI_ADDON_DIR}/${addon_id}" ] || [ -d "${KODI_USER_ADDONS}/${addon_id}" ]; then
    return 0
  fi
  echo "ERROR: required Kodi add-on missing: ${addon_id}" >&2
  return 1
}

echo "=== [install_kodi] Installing Arctic Zephyr 2 skin and dependencies ==="
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

SKIN_ID="skin.arctic.zephyr.2"
if ! kodi_install_addon "${SKIN_ID}"; then
  echo "=== [install_kodi] AZ2 mirror failed; cloning from GitHub ==="
  kodi_clone_skin_github "https://github.com/jurialmunkey/skin.arctic.zephyr.2.git" "${SKIN_ID}" \
    || SKIN_ID="skin.estuary"
fi

if [ ! -d "${KODI_ADDON_DIR}/${SKIN_ID}" ]; then
  SKIN_ID="skin.estuary"
  echo "=== [install_kodi] Using built-in Estuary skin fallback ==="
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
cp /opt/smarttv-builder/config/kodi/guisettings.xml "${KODI_CONFIG_DST}/guisettings.xml"
cp /opt/smarttv-builder/config/kodi/advancedsettings.xml "${KODI_CONFIG_DST}/advancedsettings.xml"
cp /opt/smarttv-builder/config/kodi/sources.xml "${KODI_CONFIG_DST}/sources.xml"
cp /opt/smarttv-builder/config/kodi/favourites.xml "${KODI_CONFIG_DST}/favourites.xml"

sed -i "s|<skin>.*</skin>|<skin>${SKIN_ID}</skin>|" "${KODI_CONFIG_DST}/guisettings.xml"
sed -i "s|<soundskin[^>]*>.*</soundskin>|<soundskin default=\"true\">${SKIN_ID}</soundskin>|" \
  "${KODI_CONFIG_DST}/guisettings.xml" || true

cp "${KODI_CONFIG_DST}/guisettings.xml" "${KODI_HOME}/userdata/guisettings.xml"
cp "${KODI_CONFIG_DST}/advancedsettings.xml" "${KODI_HOME}/userdata/advancedsettings.xml"
cp "${KODI_CONFIG_DST}/sources.xml" "${KODI_HOME}/userdata/sources.xml"
cp "${KODI_CONFIG_DST}/favourites.xml" "${KODI_HOME}/userdata/favourites.xml"

install -m 755 "${SCRIPT_DIR}/smarttv-kodi-bootstrap.sh" /usr/local/bin/smarttv-kodi-bootstrap.sh
install -m 755 "${SCRIPT_DIR}/kodi_install_addon.sh" /usr/local/share/smarttv/kodi_install_addon.sh

chown -R "${TARGET_USER}:${TARGET_USER}" "${KODI_HOME}"
chmod -R a+rX "${KODI_ADDON_DIR}" "${KODI_USER_ADDONS}" "${KODI_PACKAGES}" 2>/dev/null || true

kodi_require_addon "plugin.program.smarttvstore" || exit 1
kodi_require_addon "plugin.video.youtube" || exit 1
if [ "${SKIN_ID}" != "skin.estuary" ]; then
  kodi_require_addon "${SKIN_ID}" || exit 1
fi

echo "=== [install_kodi] Done (skin=${SKIN_ID}) ==="
