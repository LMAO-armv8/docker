#!/bin/bash
# setup_swap.sh — create 4GB swap file on first boot (not baked into image).

SWAPFILE="/var/swap/swapfile"
SWAP_SIZE_MB=4096
MARKER="/var/lib/smarttv/swap-configured"

if [ -f "${MARKER}" ] && swapon --show | grep -q "${SWAPFILE}"; then
  exit 0
fi

mkdir -p /var/swap /var/lib/smarttv

FREE_MB=$(df -Pm / | awk 'NR==2 {print $4}')
if [ "${FREE_MB}" -lt 4500 ]; then
  if [ "${FREE_MB}" -lt 512 ]; then
    echo "WARNING: not enough free space for swap (${FREE_MB}MB free); skipping" >&2
    exit 0
  fi
  SWAP_SIZE_MB=$((FREE_MB - 256))
  echo "WARNING: reducing swap to ${SWAP_SIZE_MB}MB due to limited SD space" >&2
fi

if [ ! -f "${SWAPFILE}" ]; then
  echo "Creating ${SWAP_SIZE_MB}MB swap at ${SWAPFILE}..."
  dd if=/dev/zero of="${SWAPFILE}" bs=1M count="${SWAP_SIZE_MB}" status=none
  chmod 600 "${SWAPFILE}"
  mkswap "${SWAPFILE}"
fi

if ! swapon --show | grep -q "${SWAPFILE}"; then
  swapon "${SWAPFILE}"
fi

if ! grep -q "${SWAPFILE}" /etc/fstab; then
  echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
fi

touch "${MARKER}"
