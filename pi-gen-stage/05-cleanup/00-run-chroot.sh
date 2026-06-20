#!/bin/bash -e
# Executed automatically inside the target chroot by pi-gen.
# Removes build-only files and APT caches so the final image stays as small
# as possible (we have a hard 4 GB uncompressed ceiling).

rm -rf /opt/smarttv-builder
rm -rf /var/lib/apt/lists/*
apt-get clean
rm -rf /tmp/* /var/tmp/*

# RetroPie-Setup itself is only needed at build time; remove it so it
# doesn't take up space on the image (cores/binaries it installed remain
# under /opt/retropie).
rm -rf /opt/retropie-setup
