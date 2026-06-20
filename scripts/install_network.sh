#!/bin/bash -e
# install_network.sh — Pi 1 onboard RJ45 (SMSC LAN9512 / smsc95xx) + DHCP.

echo "=== [install_network] Configuring onboard Ethernet (eth0) ==="

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  dhcpcd5 \
  ifupdown \
  iproute2 \
  net-tools \
  ethtool \
  iputils-ping

grep -qxF 'lan9512' /etc/modules || echo 'lan9512' >> /etc/modules
grep -qxF 'smsc95xx' /etc/modules || echo 'smsc95xx' >> /etc/modules

install -d /etc/dhcpcd.conf.d
cp /opt/smarttv-builder/config/network/dhcpcd-eth0.conf /etc/dhcpcd.conf.d/smarttv-eth0.conf

systemctl enable dhcpcd.service 2>/dev/null || true
systemctl enable dhcpcd 2>/dev/null || true

cat > /etc/systemd/system/smarttv-network-online.service <<'EOF'
[Unit]
Description=Wait for eth0 network (Smart TV)
After=dhcpcd.service network-pre.target
Before=kodi-addon-check.service kodi.service
Wants=dhcpcd.service

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=120
ExecStart=/bin/bash -c '\
  for i in $(seq 1 60); do \
    ip -4 addr show dev eth0 2>/dev/null | grep -q "inet " && exit 0; \
    sleep 2; \
  done; \
  echo "WARNING: eth0 did not get IPv4 within timeout; continuing anyway" >&2; \
  exit 0'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable smarttv-network-online.service

cat > /usr/local/bin/smarttv-network-status <<'EOF'
#!/bin/bash
echo "=== Smart TV network status ==="
ip link show eth0 2>/dev/null || echo "eth0: not found"
ip -4 addr show dev eth0 2>/dev/null || true
ethtool eth0 2>/dev/null | grep -E 'Link detected|Speed|Duplex' || true
echo "--- resolv.conf ---"
cat /etc/resolv.conf 2>/dev/null || true
EOF
chmod +x /usr/local/bin/smarttv-network-status

BOOT_CFG="/boot/config.txt"
grep -qxF 'max_usb_current=1' "${BOOT_CFG}" 2>/dev/null || echo 'max_usb_current=1' >> "${BOOT_CFG}"

echo "=== [install_network] Done ==="
