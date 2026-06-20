#!/bin/bash -e
# Generate Plymouth theme PNG assets at build time.

THEME_SRC="/opt/smarttv-builder/config/plymouth/smarttv-boot"
apt-get install -y --no-install-recommends imagemagick fonts-dejavu-core

convert -size 256x256 xc:none -fill '#66c0f4' -draw 'roundrectangle 20,20 236,236 30,30' \
  -gravity center -fill white -font DejaVu-Sans-Bold -pointsize 28 -annotate 0 'TV' \
  "${THEME_SRC}/logo.png"

for i in $(seq 0 7); do
  angle=$(( i * 45 ))
  convert -size 64x64 xc:none -stroke '#66c0f4' -strokewidth 6 \
    -draw "arc 8,8 56,56 ${angle},$((angle + 60))" \
    "${THEME_SRC}/spinner-${i}.png"
done
