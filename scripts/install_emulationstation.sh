#!/bin/bash -e
# install_emulationstation.sh — EmulationStation + Art Book Next (steam-deck theme).

echo "=== [install_emulationstation] Installing EmulationStation via RetroPie-Setup ==="

export DEBIAN_FRONTEND=noninteractive
export __platform=rpi1
export __nodialog=1

RP_SETUP_DIR="/opt/retropie-setup"
THEME_DIR="/home/pi/.emulationstation/themes/es-theme-art-book-next"

if [ ! -d "${RP_SETUP_DIR}" ]; then
  apt-get update
  apt-get install -y --no-install-recommends git dialog unzip xmlstarlet python3 build-essential cmake ca-certificates
  git clone --depth 1 https://github.com/RetroPie/RetroPie-Setup.git "${RP_SETUP_DIR}"
fi
cd "${RP_SETUP_DIR}"
chmod +x retropie_packages.sh

install_module () {
  local module="$1"
  echo "--- retropie_packages.sh ${module} install_bin ---"
  if ! ./retropie_packages.sh "${module}" install_bin clean; then
    echo "WARNING: no prebuilt 'rpi1' binary for ${module}; attempting source build."
    ./retropie_packages.sh "${module}" install_source clean \
      || echo "WARNING: ${module} could not be installed. Continuing build without it."
  fi
}

install_module emulationstation
install_module runcommand

echo "=== [install_emulationstation] Installing Art Book Next theme (steam-deck) ==="
install -d -o pi -g pi /home/pi/.emulationstation/themes
if [ ! -d "${THEME_DIR}" ]; then
  git clone --depth 1 https://github.com/anthonycaccese/art-book-next-retropie.git "${THEME_DIR}" \
    || echo "WARNING: Art Book Next theme clone failed; using Carbon fallback"
fi

if [ -f "${THEME_DIR}/theme.xml" ]; then
  sed -i 's|<colorScheme>.*</colorScheme>|<colorScheme>steam-deck</colorScheme>|' "${THEME_DIR}/theme.xml" \
    || sed -i 's|<themeVersion>.*</themeVersion>|<themeVersion>steam-deck</themeVersion>|' "${THEME_DIR}/theme.xml" \
    || true
  # Ensure steam-deck color scheme in theme.xml
  if ! grep -q 'steam-deck' "${THEME_DIR}/theme.xml"; then
    sed -i '0,/<\/theme>/s|<theme>|<theme>\n  <colorScheme>steam-deck</colorScheme>|' "${THEME_DIR}/theme.xml" 2>/dev/null || true
  fi
fi

# Carbon fallback theme
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
