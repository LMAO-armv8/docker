#!/bin/bash -e
# install_emulationstation.sh
# Runs inside the pi-gen chroot (target = Raspberry Pi 1 Model B/B+, ARMv6).
#
# Installs EmulationStation (RetroPie's fork, the de-facto standard ES build
# for Raspberry Pi) plus runcommand, the helper RetroPie/ES uses to actually
# launch a libretro core with the right settings for the chosen ROM.

echo "=== [install_emulationstation] Installing EmulationStation via RetroPie-Setup ==="

export DEBIAN_FRONTEND=noninteractive
export __platform=rpi1
export __nodialog=1

RP_SETUP_DIR="/opt/retropie-setup"

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
    echo "WARNING: no prebuilt 'rpi1' binary for ${module}; attempting to build from source (this can take a long time under QEMU emulation)."
    ./retropie_packages.sh "${module}" install_source clean \
      || echo "WARNING: ${module} could not be installed. Continuing build without it."
  fi
}

install_module emulationstation
install_module runcommand

# --- es_systems.cfg / es_input.cfg ---------------------------------------
echo "=== [install_emulationstation] Applying es_systems.cfg / es_input.cfg ==="
install -d /etc/emulationstation
cp /opt/smarttv-builder/config/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg
cp /opt/smarttv-builder/config/emulationstation/es_input.cfg /etc/emulationstation/es_input.cfg

install -d -o pi -g pi /home/pi/.emulationstation
cp /opt/smarttv-builder/config/emulationstation/es_systems.cfg /home/pi/.emulationstation/es_systems.cfg
cp /opt/smarttv-builder/config/emulationstation/es_input.cfg /home/pi/.emulationstation/es_input.cfg
chown -R pi:pi /home/pi/.emulationstation

chown -R pi:pi /opt/retropie 2>/dev/null || true

echo "=== [install_emulationstation] Done ==="
