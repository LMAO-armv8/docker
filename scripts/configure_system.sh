#!/bin/bash -e
# configure_system.sh — system integration for Smart TV Retro Pi 1 image.

echo "=== [configure_system] Configuring system ==="

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="pi"
BOOT_CFG="/boot/config.txt"
BUILDER="/opt/smarttv-builder/scripts"

apt-get update
apt-get install -y --no-install-recommends xboxdrv joystick udev

# Sub-installers (network, browser, boot animation, wallpapers, swap)
for script in install_network.sh install_browser.sh generate_plymouth_assets.sh \
  install_boot_animation.sh install_wallpapers.sh; do
  if [ -x "${BUILDER}/${script}" ]; then
    "${BUILDER}/${script}"
  fi
done

# Swap + systemd units
install -m 755 /opt/smarttv-builder/scripts/setup_swap.sh /usr/local/bin/setup_swap.sh
install -m 755 /opt/smarttv-builder/scripts/kodi_addon_check.sh /usr/local/bin/kodi_addon_check.sh
install -m 644 /opt/smarttv-builder/config/systemd/smarttv-swap.service /etc/systemd/system/
install -m 644 /opt/smarttv-builder/config/systemd/kodi-addon-check.service /etc/systemd/system/
systemctl enable smarttv-swap.service
systemctl enable kodi-addon-check.service

# Keep add-on helper after pi-gen cleanup stage removes /opt/smarttv-builder
install -d /usr/local/share/smarttv
install -m 755 /opt/smarttv-builder/scripts/kodi_install_addon.sh /usr/local/share/smarttv/

systemctl enable ssh
echo "${TARGET_USER}:raspberry" | chpasswd

grep -qxF 'uinput' /etc/modules || echo 'uinput' >> /etc/modules
grep -qxF 'joydev' /etc/modules || echo 'joydev' >> /etc/modules
usermod -aG input,plugdev,video,audio,tty,dialout "${TARGET_USER}"

cat > /etc/systemd/system/xboxdrv.service <<'EOF'
[Unit]
Description=xboxdrv generic Xbox-style USB/Bluetooth controller driver
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/xboxdrv --daemon --silent --detach-kernel-driver
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl enable xboxdrv.service

grep -q '^gpu_mem=' "${BOOT_CFG}" 2>/dev/null \
  && sed -i 's/^gpu_mem=.*/gpu_mem=128/' "${BOOT_CFG}" \
  || echo 'gpu_mem=128' >> "${BOOT_CFG}"
grep -qxF 'hdmi_force_hotplug=1' "${BOOT_CFG}" || echo 'hdmi_force_hotplug=1' >> "${BOOT_CFG}"
grep -qxF 'disable_overscan=1' "${BOOT_CFG}" || echo 'disable_overscan=1' >> "${BOOT_CFG}"

systemctl disable getty@tty1.service 2>/dev/null || true

cat > /etc/systemd/system/kodi.service <<'EOF'
[Unit]
Description=Kodi standalone (auto-boot, no desktop)
After=smarttv-swap.service smarttv-network-online.service sound.target xboxdrv.service
Wants=smarttv-swap.service xboxdrv.service

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
ExecStartPre=/usr/local/bin/smarttv-boot-splash.sh
ExecStart=/usr/local/bin/kodi-standalone-wrapper.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl set-default multi-user.target
systemctl enable kodi.service

cat > /usr/local/bin/launch-emulationstation.sh <<'EOF'
#!/bin/bash
systemctl stop kodi.service
runuser -l pi -c '/opt/retropie/supplementary/emulationstation/emulationstation' < /dev/tty1 > /dev/tty1 2>&1
systemctl start kodi.service
EOF
chmod +x /usr/local/bin/launch-emulationstation.sh

echo "=== [configure_system] Done ==="
