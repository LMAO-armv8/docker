#!/bin/bash -e
# install_emulationstation.sh — EmulationStation + Art Book Next (steam-deck theme).

echo "=== [install_emulationstation] Installing EmulationStation via RetroPie-Setup ==="

BUILDER="/opt/smarttv-builder/scripts"
# shellcheck source=/dev/null
source "${BUILDER}/retropie_common.sh"

retropie_prepare_setup

retropie_install_module emulationstation
retropie_install_runcommand

echo "=== [install_emulationstation] Installing Art Book Next theme (steam-deck) ==="
THEME_DIR="/home/pi/.emulationstation/themes/es-theme-art-book-next"
install -d -o pi -g pi /home/pi/.emulationstation/themes
if [ ! -d "${THEME_DIR}" ]; then
  git clone --depth 1 https://github.com/anthonycaccese/art-book-next-retropie.git "${THEME_DIR}" \
    || echo "WARNING: Art Book Next theme clone failed; using Carbon fallback"
fi

if [ -f "${THEME_DIR}/theme.xml" ]; then
  sed -i 's|<colorScheme>.*</colorScheme>|<colorScheme>steam-deck</colorScheme>|' "${THEME_DIR}/theme.xml" \
    || sed -i 's|<themeVersion>.*</themeVersion>|<themeVersion>steam-deck</themeVersion>|' "${THEME_DIR}/theme.xml" \
    || true
  if ! grep -q 'steam-deck' "${THEME_DIR}/theme.xml"; then
    sed -i '0,/<\/theme>/s|<theme>|<theme>\n  <colorScheme>steam-deck</colorScheme>|' "${THEME_DIR}/theme.xml" 2>/dev/null || true
  fi
fi

if [ ! -d /home/pi/.emulationstation/themes/es-theme-carbon ]; then
  git clone --depth 1 https://github.com/RetroPie/es-theme-carbon.git /home/pi/.emulationstation/themes/es-theme-carbon \
    || true
fi

echo "=== [install_emulationstation] Applying es_systems.cfg / es_input.cfg / themes.xml ==="
install -d /etc/emulationstation
cp /opt/smarttv-builder/config/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg
cp /opt/smarttv-builder/config/emulationstation/es_input.cfg /etc/emulationstation/es_input.cfg

install -d -o pi -g pi /home/pi/.emulationstation
cp /opt/smarttv-builder/config/emulationstation/es_systems.cfg /home/pi/.emulationstation/es_systems.cfg
cp /opt/smarttv-builder/config/emulationstation/es_input.cfg /home/pi/.emulationstation/es_input.cfg
cp /opt/smarttv-builder/config/emulationstation/themes.xml /home/pi/.emulationstation/themes.xml
cp /opt/smarttv-builder/config/emulationstation/es_settings.cfg /home/pi/.emulationstation/es_settings.cfg

install -d -o pi -g pi "${THEME_DIR}/_inc" 2>/dev/null || true

chown -R pi:pi /home/pi/.emulationstation
chown -R pi:pi /opt/retropie 2>/dev/null || true

echo "=== [install_emulationstation] Done ==="
