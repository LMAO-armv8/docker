#!/bin/bash -e
# install_kodi_store.sh — install plugin.program.smarttvstore and CLI wrapper.

echo "=== [install_kodi_store] Installing Smart TV App Store ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE_SRC="/opt/smarttv-builder/addons/plugin.program.smarttvstore"
KODI_ADDON_DIR="/usr/share/kodi/addons"
KODI_USER_ADDONS="/home/pi/.kodi/addons"
KODI_STORE_PERSIST="/usr/local/share/smarttv/plugin.program.smarttvstore"

rm -rf "${KODI_ADDON_DIR}/plugin.program.smarttvstore" \
  "${KODI_USER_ADDONS}/plugin.program.smarttvstore" \
  "${KODI_STORE_PERSIST}"
cp -a "${STORE_SRC}" "${KODI_ADDON_DIR}/plugin.program.smarttvstore"
cp -a "${STORE_SRC}" "${KODI_USER_ADDONS}/plugin.program.smarttvstore"
cp -a "${STORE_SRC}" "${KODI_STORE_PERSIST}"
chmod -R a+rX "${KODI_ADDON_DIR}/plugin.program.smarttvstore" \
  "${KODI_USER_ADDONS}/plugin.program.smarttvstore" \
  "${KODI_STORE_PERSIST}"
chown -R pi:pi "${KODI_USER_ADDONS}/plugin.program.smarttvstore"

install -d /usr/local/share/smarttv
install -m 755 "${SCRIPT_DIR}/kodi_install_addon.sh" /usr/local/share/smarttv/kodi_install_addon.sh

cat > /usr/local/bin/smarttv-install-addon <<'EOF'
#!/bin/bash
set -e
export KODI_ADDON_DIR="/usr/share/kodi/addons"
export KODI_USER_ADDON_DIR="/home/pi/.kodi/addons"
export KODI_SAVE_PACKAGES_DIR="/usr/local/share/smarttv/addon-packages"
# shellcheck source=/dev/null
source /usr/local/share/smarttv/kodi_install_addon.sh
if [ $# -lt 1 ]; then
  echo "Usage: smarttv-install-addon <addon.id> [pinned-zip-name]" >&2
  exit 1
fi
kodi_install_addon "$1" "${2:-}"
EOF
chmod +x /usr/local/bin/smarttv-install-addon

echo "=== [install_kodi_store] Done ==="
