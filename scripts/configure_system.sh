#!/bin/bash -e
# configure_system.sh
# Runs inside the pi-gen chroot (target = Raspberry Pi 1 Model B/B+, ARMv6).
#
# Wires everything installed by install_kodi.sh / install_retroarch.sh /
# install_emulationstation.sh into a system that boots straight into Kodi
# with no desktop and no terminal, has SSH on by default, and recognises a
# generic Xbox-style USB/Bluetooth controller via xboxdrv.

echo "=== [configure_system] Configuring system ==="

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="pi"
BOOT_CFG="/boot/config.txt"

apt-get update
apt-get install -y --no-install-recommends xboxdrv joystick udev

# --------------------------------------------------------------------------
# 1. SSH enabled by default
# --------------------------------------------------------------------------
systemctl enable ssh

# pi-gen already created the default user/password from this repo's pi-gen
# config (FIRST_USER_NAME=pi, FIRST_USER_PASS=raspberry). Set it again here
# explicitly so it's correct even if you change pi-gen's config defaults
# without updating this script.
echo "${TARGET_USER}:raspberry" | chpasswd

# --------------------------------------------------------------------------
# 2. Controller support: USB/Bluetooth HID joysticks (joydev, built into the
#    kernel) plus xboxdrv for proper XInput-style Xbox-controller support.
# --------------------------------------------------------------------------
grep -qxF 'uinput' /etc/modules || echo 'uinput' >> /etc/modules
grep -qxF 'joydev' /etc/modules || echo 'joydev' >> /etc/modules

usermod -aG input,plugdev,video,audio,tty,dialout "${TARGET_USER}"

cat > /etc/systemd/system/xboxdrv.service <<'EOF'
[Unit]
Description=xboxdrv generic Xbox-style USB/Bluetooth controller driver
After=local-fs.target

[Service]
Type=simple
# --detach-kernel-driver hands control from the in-kernel xpad driver to
# xboxdrv so it can expose a unified XInput-style /dev/input device, as
# requested (HID + XInput via xboxdrv). --silent keeps the journal quiet.
ExecStart=/usr/bin/xboxdrv --daemon --silent --detach-kernel-driver
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl enable xboxdrv.service

# --------------------------------------------------------------------------
# 3. Boot config: GPU memory split for Kodi video decode / RetroArch GLES
# --------------------------------------------------------------------------
# Pi 1 Model B has 256MB total RAM, B+ commonly ships 512MB. 128MB is a safe
# default that leaves enough headroom for the OS on a 256MB board; raise to
# 160-192 in /boot/config.txt if you know you're on a 512MB B+.
grep -q '^gpu_mem=' "${BOOT_CFG}" 2>/dev/null \
  && sed -i 's/^gpu_mem=.*/gpu_mem=128/' "${BOOT_CFG}" \
  || echo 'gpu_mem=128' >> "${BOOT_CFG}"

grep -qxF 'hdmi_force_hotplug=1' "${BOOT_CFG}" || echo 'hdmi_force_hotplug=1' >> "${BOOT_CFG}"
grep -qxF 'disable_overscan=1' "${BOOT_CFG}" || echo 'disable_overscan=1' >> "${BOOT_CFG}"

# --------------------------------------------------------------------------
# 4. Auto-boot straight into Kodi - no desktop, no terminal.
#    We replace the tty1 getty with our own systemd unit that runs Kodi in
#    standalone mode directly on the console framebuffer (dispmanx/EGL on
#    Buster's legacy graphics stack), so nothing but Kodi is ever shown.
# --------------------------------------------------------------------------
systemctl disable getty@tty1.service 2>/dev/null || true

cat > /etc/systemd/system/kodi.service <<'EOF'
[Unit]
Description=Kodi standalone (auto-boot, no desktop)
After=systemd-user-sessions.service network.target sound.target xboxdrv.service
Wants=xboxdrv.service

[Service]
User=pi
Group=pi
Type=simple
PAMName=login
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
ExecStart=/usr/bin/kodi-standalone
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl set-default multi-user.target
systemctl enable kodi.service

# --------------------------------------------------------------------------
# 5. Kodi <-> EmulationStation bridge.
#    Kodi's pre-baked favourites.xml (see install_kodi.sh / config/kodi)
#    contains a "Retro Games" shortcut that calls this script. It stops
#    Kodi, runs EmulationStation full-screen on the same console, and
#    restarts Kodi automatically once you quit EmulationStation (Start +
#    Select by default, see README.md).
# --------------------------------------------------------------------------
cat > /usr/local/bin/launch-emulationstation.sh <<'EOF'
#!/bin/bash
# Switches the console from Kodi to EmulationStation and back again.
systemctl stop kodi.service
runuser -l pi -c '/opt/retropie/supplementary/emulationstation/emulationstation' < /dev/tty1 > /dev/tty1 2>&1
systemctl start kodi.service
EOF
chmod +x /usr/local/bin/launch-emulationstation.sh

echo "=== [configure_system] Done ==="
