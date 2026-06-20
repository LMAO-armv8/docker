#!/bin/bash -e
# kodi_addon_check.sh — log add-on status once network is up.

LOG="/var/log/kodi-addon-check.log"
MARKER="/var/lib/smarttv/addon-check-done"
KODI_ADDON_DIR="/usr/share/kodi/addons"

mkdir -p /var/lib/smarttv
if [ -f "${MARKER}" ]; then
  exit 0
fi

{
  echo "=== Smart TV add-on check $(date -Is) ==="
  for id in plugin.video.youtube skin.arctic.zephyr.2 plugin.program.smarttvstore; do
    if [ -d "${KODI_ADDON_DIR}/${id}" ]; then
      echo "OK: ${id}"
    else
      echo "MISSING: ${id}"
    fi
  done
  echo "Run: smarttv-install-addon <id> to install missing add-ons"
} >> "${LOG}" 2>&1

touch "${MARKER}"
