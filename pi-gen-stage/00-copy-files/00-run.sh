#!/bin/bash -e
# Runs on the BUILD HOST (not inside the chroot). Copies this repo's
# scripts/ and config/ folders (placed alongside this file by the CI
# workflow, see .github/workflows/build.yml) into the target rootfs so the
# 00-run-chroot.sh scripts in the later steps of this stage can call them.

install -d "${ROOTFS_DIR}/opt/smarttv-builder"
cp -r files/scripts "${ROOTFS_DIR}/opt/smarttv-builder/scripts"
cp -r files/config "${ROOTFS_DIR}/opt/smarttv-builder/config"
if [ -d files/addons ]; then
  cp -r files/addons "${ROOTFS_DIR}/opt/smarttv-builder/addons"
fi

# scripts are checked out without the executable bit on some checkouts/OSes
chmod +x "${ROOTFS_DIR}"/opt/smarttv-builder/scripts/*.sh
