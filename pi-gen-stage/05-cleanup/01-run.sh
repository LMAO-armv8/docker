#!/bin/bash -e
# Host-side (not chroot): release /dev bind mounts before pi-gen unloads qcow2.
# Without this, leftover qemu-user-static helpers can block umount with
# "target is busy" on self-hosted and GitHub-hosted runners.

if [[ -z "${ROOTFS_DIR:-}" ]] || [[ ! -d "${ROOTFS_DIR}/dev" ]]; then
  exit 0
fi

echo "=== [cleanup] Releasing chroot bind mounts ==="

for _ in 1 2 3 4 5; do
  fuser -vm "${ROOTFS_DIR}/dev" -k 2>/dev/null || true
  sleep 1

  for mp in "${ROOTFS_DIR}/dev/pts" "${ROOTFS_DIR}/dev" "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys"; do
    if mountpoint -q "${mp}" 2>/dev/null; then
      umount -l "${mp}" 2>/dev/null || umount "${mp}" 2>/dev/null || true
    fi
  done

  mountpoint -q "${ROOTFS_DIR}/dev" 2>/dev/null || break
done

if mountpoint -q "${ROOTFS_DIR}/dev" 2>/dev/null; then
  echo "WARNING: ${ROOTFS_DIR}/dev still mounted; pi-gen may retry lazy umount"
fi

echo "=== [cleanup] Done releasing bind mounts ==="
