#!/bin/bash -e
# install_boot_animation.sh — silent boot + Plymouth smarttv-boot theme.

echo "=== [install_boot_animation] Configuring silent boot and Plymouth ==="

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends plymouth plymouth-themes fbset

if [ -x /opt/smarttv-builder/scripts/generate_plymouth_assets.sh ]; then
  /opt/smarttv-builder/scripts/generate_plymouth_assets.sh
fi

THEME_DIR="/usr/share/plymouth/themes/smarttv-boot"
mkdir -p "${THEME_DIR}"
cp -r /opt/smarttv-builder/config/plymouth/smarttv-boot/* "${THEME_DIR}/"

plymouth-set-default-theme smarttv-boot 2>/dev/null || \
  ln -sf "${THEME_DIR}/smarttv-boot.plymouth" /etc/alternatives/default.plymouth 2>/dev/null || true

update-initramfs -u -k all 2>/dev/null || update-initramfs -u 2>/dev/null || true

BOOT_CFG="/boot/config.txt"
CMDLINE="/boot/cmdline.txt"

grep -qxF 'disable_splash=1' "${BOOT_CFG}" 2>/dev/null || echo 'disable_splash=1' >> "${BOOT_CFG}"
grep -qxF 'avoid_warnings=1' "${BOOT_CFG}" 2>/dev/null || echo 'avoid_warnings=1' >> "${BOOT_CFG}"

if [ -f "${CMDLINE}" ]; then
  if [ -f /boot/debug-boot ]; then
    echo "DEBUG: /boot/debug-boot present — leaving cmdline unchanged"
  else
    CL=$(tr -d '\n' < "${CMDLINE}")
    CL=$(echo "${CL}" | sed 's/console=tty1/console=tty3/g')
    for param in quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0 systemd.show_status=0 plymouth.ignore-serial-consoles; do
      echo "${CL}" | grep -q "${param}" || CL="${CL} ${param}"
    done
    echo "${CL}" > "${CMDLINE}"
  fi
fi

cat > /usr/local/bin/kodi-standalone-wrapper.sh <<'EOF'
#!/bin/bash
/usr/bin/plymouth display-message --text="Starting Smart TV..." 2>/dev/null || true
/usr/bin/plymouth quit 2>/dev/null || true
exec /usr/bin/kodi-standalone "$@"
EOF
chmod +x /usr/local/bin/kodi-standalone-wrapper.sh

cat > /etc/systemd/system/smarttv-quiet-console.service <<'EOF'
[Unit]
Description=Suppress late dmesg on console
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/dmesg --console-off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable smarttv-quiet-console.service

if ! grep -q 'dmesg --console-off' /etc/rc.local 2>/dev/null; then
  if [ -f /etc/rc.local ]; then
    sed -i '/^exit 0/i dmesg --console-off 2>/dev/null || true' /etc/rc.local
  else
    cat > /etc/rc.local <<'RC'
#!/bin/sh -e
dmesg --console-off 2>/dev/null || true
exit 0
RC
    chmod +x /etc/rc.local
  fi
fi

cat > /etc/sysctl.d/99-smarttv-swap.conf <<'EOF'
vm.swappiness=40
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

echo "=== [install_boot_animation] Done ==="
