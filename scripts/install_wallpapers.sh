#!/bin/bash -e
# install_wallpapers.sh — generate wallpaper packs and enable rotation timer.

echo "=== [install_wallpapers] Installing dynamic wallpapers ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends imagemagick fbi fonts-dejavu-core

WALL_ROOT="/usr/share/smarttv/wallpapers"
mkdir -p "${WALL_ROOT}"/{boot,kodi,es,time/morning,time/afternoon,time/night}
mkdir -p /home/pi/smarttv-wallpapers/custom
chown -R pi:pi /home/pi/smarttv-wallpapers

gen_wall() {
  local out="$1"
  local c1="$2"
  local c2="$3"
  local label="$4"
  convert -size 1280x720 "gradient:${c1}-${c2}" \
    -gravity center -fill white -font DejaVu-Sans-Bold -pointsize 48 -annotate 0 "${label}" \
    "${out}"
}

gen_wall "${WALL_ROOT}/boot/boot-01.jpg" "#1b2838" "#2a475e" "Smart TV Retro"
gen_wall "${WALL_ROOT}/boot/boot-02.jpg" "#171a21" "#1b2838" "Loading..."
gen_wall "${WALL_ROOT}/boot/boot-03.jpg" "#0e1419" "#1b2838" "Pi 1 Edition"

for i in 1 2 3 4 5 6; do
  gen_wall "${WALL_ROOT}/kodi/kodi-${i}.jpg" "#1b2838" "#2d5a87" "Smart TV ${i}"
  gen_wall "${WALL_ROOT}/es/es-${i}.jpg" "#171a21" "#3d4450" "Retro ${i}"
done

cp "${WALL_ROOT}/kodi/kodi-"*.jpg "${WALL_ROOT}/time/morning/"
cp "${WALL_ROOT}/kodi/kodi-"*.jpg "${WALL_ROOT}/time/afternoon/"
cp "${WALL_ROOT}/kodi/kodi-"*.jpg "${WALL_ROOT}/time/night/"

install -m 755 /opt/smarttv-builder/scripts/smarttv-wallpaper-rotate.sh /usr/local/bin/smarttv-wallpaper-rotate.sh
/usr/local/bin/smarttv-wallpaper-rotate.sh

install -m 644 /opt/smarttv-builder/config/systemd/smarttv-wallpaper.service /etc/systemd/system/
install -m 644 /opt/smarttv-builder/config/systemd/smarttv-wallpaper.timer /etc/systemd/system/
systemctl enable smarttv-wallpaper.timer

cat > /usr/local/bin/smarttv-boot-splash.sh <<'SPLASH'
#!/bin/bash
if [ -f /run/plymouth/pid ] || [ -f /boot/debug-boot ]; then
  exit 0
fi
for img in /usr/share/smarttv/wallpapers/boot/*.jpg; do
  [ -f "$img" ] || continue
  fbi -T 1 -a -noverbose -once "$img" 2>/dev/null || true
  sleep 1
done
SPLASH
chmod +x /usr/local/bin/smarttv-boot-splash.sh

echo "=== [install_wallpapers] Done ==="
