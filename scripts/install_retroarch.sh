#!/bin/bash -e
# install_retroarch.sh
# Runs inside the pi-gen chroot (target = Raspberry Pi 1 Model B/B+, ARMv6).

echo "=== [install_retroarch] Installing RetroArch + cores via RetroPie-Setup ==="

BUILDER="/opt/smarttv-builder/scripts"
# shellcheck source=/dev/null
source "${BUILDER}/retropie_common.sh"

retropie_prepare_setup

for module in retroarch \
  lr-fceumm lr-snes9x2010 lr-gpsp lr-picodrive lr-pcsx-rearmed lr-mupen64plus; do
  retropie_install_module "${module}"
done

echo "=== [install_retroarch] Applying retroarch.cfg ==="
install -d /opt/retropie/configs/all
cp /opt/smarttv-builder/config/retroarch/retroarch.cfg /opt/retropie/configs/all/retroarch.cfg

install -d -o pi -g pi /home/pi/RetroPie/roms
chown -R pi:pi /opt/retropie /home/pi/RetroPie 2>/dev/null || true

echo "=== [install_retroarch] Done ==="
