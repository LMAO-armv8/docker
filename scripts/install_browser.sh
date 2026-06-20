#!/bin/bash -e
# install_browser.sh — Midori + minimal X stack for web browsing from Kodi.

echo "=== [install_browser] Installing Midori browser ==="

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  midori \
  xserver-xorg \
  xinit \
  openbox \
  dbus-x11 \
  matchbox-window-manager

cat > /usr/local/bin/launch-browser.sh <<'EOF'
#!/bin/bash
systemctl stop kodi.service
export DISPLAY=:0
runuser -l pi -c 'startx /usr/bin/midori -a https://www.google.com/ -- :0 vt1 -nocursor' < /dev/tty1 > /dev/tty1 2>&1
systemctl start kodi.service
EOF
chmod +x /usr/local/bin/launch-browser.sh

echo "=== [install_browser] Done ==="
