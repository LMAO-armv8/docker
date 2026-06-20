#!/bin/bash -e
# install_retroarch.sh
# Runs inside the pi-gen chroot (target = Raspberry Pi 1 Model B/B+, ARMv6).
#
# Installs RetroArch and the requested libretro cores using RetroPie-Setup's
# documented non-interactive package interface:
#   ./retropie_packages.sh <module_id> <mode> [clean]
# This is the same mechanism RetroPie's own automated builds use, and it is
# platform-aware (picks prebuilt binaries for the "rpi1" platform tag when
# available, which covers ARMv6 Pi 1/Zero).
#
# Hardware reality check (Pi 1 = single core ARM11 @ 700MHz, no NEON, 256-512MB
# RAM): NES/SNES/GBA/Genesis run well. PS1 runs at reduced/inconsistent speed
# for simple 2D-heavy titles only. N64 is included because it was explicitly
# requested ("as far as Pi 1 can handle"), but realistically expect it to be
# unplayably slow or not boot at all - there is no light N64 core, and even a
# Pi 3 struggles with mupen64plus. See README.md "Limitations".

echo "=== [install_retroarch] Installing RetroArch + cores via RetroPie-Setup ==="

export DEBIAN_FRONTEND=noninteractive
export __platform=rpi1   # force platform: /proc/cpuinfo inside a qemu chroot
                          # reflects the build host, not the Pi 1 target, so
                          # RetroPie-Setup's auto-detection cannot be trusted.
export __nodialog=1
# pi-gen chroot inherits SUDO_USER from the build host (e.g. "runner" on
# GitHub Actions). retropie_packages.sh uses that to pick the install user.
export __user=pi
export SUDO_USER=pi

RP_SETUP_DIR="/opt/retropie-setup"

apt-get update
apt-get install -y --no-install-recommends \
  git dialog unzip xmlstarlet python3 build-essential cmake \
  libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libsdl2-mixer-dev \
  libfreeimage-dev libfreetype6-dev libcurl4-openssl-dev rapidjson-dev \
  ca-certificates

if [ ! -d "${RP_SETUP_DIR}" ]; then
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
      || echo "WARNING: ${module} could not be installed (binary and source both failed). Continuing build without it."
  fi
}

# Core RetroArch frontend + default configs/joypad autoconfig profiles.
install_module retroarch

# Requested systems:
install_module lr-fceumm           # NES / Famicom
install_module lr-snes9x2010       # SNES (the "2010" fork is tuned for low-power ARMv6/ARMv7 devices)
install_module lr-gpsp             # Game Boy Advance (designed for weak hardware, ideal for Pi 1)
install_module lr-picodrive        # Sega Genesis / Mega Drive (lighter than Genesis Plus GX, recommended for Pi 1)
install_module lr-pcsx-rearmed     # PlayStation 1 - expect reduced/inconsistent performance on Pi 1
install_module lr-mupen64plus      # N64 - included as requested; realistically not playable on Pi 1 hardware

# --- retroarch.cfg with controller mappings ------------------------------
# RetroPie's global config lives at /opt/retropie/configs/all/retroarch.cfg
echo "=== [install_retroarch] Applying retroarch.cfg ==="
install -d /opt/retropie/configs/all
cp /opt/smarttv-builder/config/retroarch/retroarch.cfg /opt/retropie/configs/all/retroarch.cfg

# RetroPie creates a roms tree under the target user's home directory.
install -d -o pi -g pi /home/pi/RetroPie/roms

chown -R pi:pi /opt/retropie /home/pi/RetroPie 2>/dev/null || true

echo "=== [install_retroarch] Done ==="
