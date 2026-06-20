#!/bin/bash
# smarttv-wallpaper-rotate.sh — rotate Kodi / ES background images.

WALLPAPER_ROOT="/usr/share/smarttv/wallpapers"
CUSTOM_DIR="/home/pi/smarttv-wallpapers/custom"
KODI_CURRENT="${WALLPAPER_ROOT}/kodi/current.jpg"
ES_BG="/home/pi/.emulationstation/themes/es-theme-art-book-next/_inc/background.jpg"
STATE="/var/lib/smarttv/wallpaper-index"

pick_pool() {
  local pool="${WALLPAPER_ROOT}/kodi"
  local hour
  hour=$(date +%H)
  if [ -d "${WALLPAPER_ROOT}/time" ]; then
    if [ "${hour}" -lt 12 ] && [ -d "${WALLPAPER_ROOT}/time/morning" ]; then
      pool="${WALLPAPER_ROOT}/time/morning"
    elif [ "${hour}" -lt 18 ] && [ -d "${WALLPAPER_ROOT}/time/afternoon" ]; then
      pool="${WALLPAPER_ROOT}/time/afternoon"
    elif [ -d "${WALLPAPER_ROOT}/time/night" ]; then
      pool="${WALLPAPER_ROOT}/time/night"
    fi
  fi
  echo "${pool}"
}

POOL=$(pick_pool)
mapfile -t FILES < <(find "${POOL}" "${CUSTOM_DIR}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' \) 2>/dev/null | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
  exit 0
fi

IDX=0
if [ -f "${STATE}" ]; then
  IDX=$(cat "${STATE}")
fi
IDX=$(( (IDX + 1) % ${#FILES[@]} ))
echo "${IDX}" > "${STATE}"

NEXT="${FILES[$IDX]}"
mkdir -p "$(dirname "${KODI_CURRENT}")" /var/lib/smarttv
cp -f "${NEXT}" "${KODI_CURRENT}"
chmod a+r "${KODI_CURRENT}"

if [ -d "$(dirname "${ES_BG}")" ]; then
  cp -f "${NEXT}" "${ES_BG}" 2>/dev/null || ln -sf "${KODI_CURRENT}" "${ES_BG}" 2>/dev/null || true
  chown -R pi:pi "$(dirname "${ES_BG}")" 2>/dev/null || true
fi

ES_THEME="/home/pi/.emulationstation/themes/es-theme-art-book-next/_inc"
if [ -d "${ES_THEME}" ]; then
  ln -sf "${KODI_CURRENT}" "${ES_THEME}/background.jpg" 2>/dev/null || cp -f "${KODI_CURRENT}" "${ES_THEME}/background.jpg" 2>/dev/null || true
  chown -R pi:pi "${ES_THEME}" 2>/dev/null || true
fi
