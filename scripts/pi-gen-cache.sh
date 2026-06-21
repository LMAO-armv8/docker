#!/bin/bash
# pi-gen-cache.sh — persistent pi-gen work cache for self-hosted / server builds.
#
# Caches qcow2 stage images under PI_GEN_CACHE_DIR so restarts can skip stage0–2
# (Raspberry Pi OS Lite base) when nothing base-related changed, and resume
# stage5-smarttv when only custom scripts/config changed.
#
# Usage (from repo root):
#   scripts/pi-gen-cache.sh clean
#   scripts/pi-gen-cache.sh clone-pigen
#   scripts/pi-gen-cache.sh prepare
#   scripts/pi-gen-cache.sh save
#
# Env:
#   PI_GEN_CACHE_DIR  default /var/cache/smarttv-pi-gen
#   IMG_NAME          default smarttv-retro-pi1
#   PI_GEN_BRANCH     default buster
#   REPO_ROOT         default $(pwd)

set -euo pipefail

CACHE_VERSION=1
IMG_NAME="${IMG_NAME:-smarttv-retro-pi1}"
PI_GEN_BRANCH="${PI_GEN_BRANCH:-buster}"
PI_GEN_CACHE_DIR="${PI_GEN_CACHE_DIR:-/var/cache/smarttv-pi-gen}"
REPO_ROOT="${REPO_ROOT:-$(pwd)}"
PI_GEN_DIR="${PI_GEN_DIR:-${REPO_ROOT}/pi-gen}"
WORK_DIR="${PI_GEN_DIR}/work/${IMG_NAME}"
WORK_CACHE="${PI_GEN_CACHE_DIR}/work/${IMG_NAME}"
GIT_MIRROR="${PI_GEN_CACHE_DIR}/mirrors/pi-gen.git"
PI_GEN_UPSTREAM="${PI_GEN_UPSTREAM:-https://github.com/RPi-Distro/pi-gen.git}"

mkdir -p "${PI_GEN_CACHE_DIR}"

base_cache_key() {
  printf '%s:%s:%s\n' "${CACHE_VERSION}" "${PI_GEN_BRANCH}" "base-v1" \
    | sha256sum | awk '{print $1}' | cut -c1-16
}

stage5_cache_key() {
  {
    find "${REPO_ROOT}/pi-gen-stage" "${REPO_ROOT}/scripts" "${REPO_ROOT}/config" \
      \( -path "${REPO_ROOT}/scripts/build-server.sh" \
      -o -path "${REPO_ROOT}/scripts/pi-gen-cache.sh" \) -prune \
      -o -type f -print 2>/dev/null | sort
    if [[ -d "${REPO_ROOT}/addons" ]]; then
      find "${REPO_ROOT}/addons" -type f 2>/dev/null | sort
    fi
  } | while read -r f; do
    [[ -n "${f}" ]] && sha256sum "${f}"
  done | sha256sum | awk '{print $1}' | cut -c1-16
}

cmd_clean() {
  echo "=== [pi-gen-cache] Removing cache at ${PI_GEN_CACHE_DIR} ==="
  rm -rf "${PI_GEN_CACHE_DIR}/work" "${PI_GEN_CACHE_DIR}/mirrors"
  rm -f "${PI_GEN_CACHE_DIR}/base.key" "${PI_GEN_CACHE_DIR}/stage5.key"
}

cmd_clone_pigen() {
  mkdir -p "${PI_GEN_CACHE_DIR}/mirrors"
  if [[ ! -d "${GIT_MIRROR}" ]]; then
    echo "=== [pi-gen-cache] Seeding pi-gen mirror ==="
    git clone --mirror --branch "${PI_GEN_BRANCH}" "${PI_GEN_UPSTREAM}" "${GIT_MIRROR}"
  else
    echo "=== [pi-gen-cache] Updating pi-gen mirror ==="
    git -C "${GIT_MIRROR}" fetch --depth 1 origin "${PI_GEN_BRANCH}" 2>/dev/null \
      || git -C "${GIT_MIRROR}" fetch origin
  fi

  rm -rf "${PI_GEN_DIR}"
  echo "=== [pi-gen-cache] Cloning pi-gen from local mirror ==="
  git clone --depth 1 --branch "${PI_GEN_BRANCH}" "${GIT_MIRROR}" "${PI_GEN_DIR}"
}

restore_work_tree() {
  [[ -d "${WORK_CACHE}" ]] || return 0
  echo "=== [pi-gen-cache] Restoring work tree from ${WORK_CACHE} ==="
  mkdir -p "${WORK_DIR}"
  rsync -aH "${WORK_CACHE}/" "${WORK_DIR}/"
  validate_work_qcow2 "${WORK_DIR}" || invalidate_work_qcow2 "${WORK_DIR}"
  ls -lh "${WORK_DIR}"/image-*.qcow2 2>/dev/null || true
}

validate_qcow2() {
  local img="$1"
  [[ -f "${img}" ]] || return 0
  echo "=== [pi-gen-cache] Checking ${img} ==="
  if qemu-img check "${img}" >/dev/null 2>&1; then
    return 0
  fi
  echo "WARNING: corrupt or incomplete qcow2: ${img}"
  return 1
}

validate_work_qcow2() {
  local work="$1"
  local img failed=0
  shopt -s nullglob
  local images=("${work}"/image-*.qcow2)
  shopt -u nullglob
  [[ ${#images[@]} -gt 0 ]] || return 0
  for img in "${images[@]}"; do
    if ! validate_qcow2 "${img}"; then
      failed=1
      rm -f "${img}"
    fi
  done
  [[ "${failed}" -eq 0 ]]
}

invalidate_work_qcow2() {
  local work="$1"
  echo "=== [pi-gen-cache] Invalidating cached qcow2 images ==="
  rm -f "${work}"/image-*.qcow2
  rm -rf "${work}"/stage0 "${work}"/stage1 "${work}"/stage2 "${work}"/stage5-smarttv
}

cmd_prepare() {
  local bk sk
  bk="$(base_cache_key)"
  sk="$(stage5_cache_key)"

  restore_work_tree

  if [[ ! -f "${PI_GEN_CACHE_DIR}/base.key" ]] || [[ "$(cat "${PI_GEN_CACHE_DIR}/base.key")" != "${bk}" ]]; then
    echo "=== [pi-gen-cache] Base cache key changed (${bk}); invalidating stage0–2 qcow2 ==="
    rm -f "${WORK_DIR}/image-stage0.qcow2" "${WORK_DIR}/image-stage1.qcow2" \
      "${WORK_DIR}/image-stage2.qcow2"
    rm -rf "${WORK_DIR}/stage0" "${WORK_DIR}/stage1" "${WORK_DIR}/stage2"
    echo "${bk}" > "${PI_GEN_CACHE_DIR}/base.key"
  fi

  if [[ ! -f "${PI_GEN_CACHE_DIR}/stage5.key" ]] || [[ "$(cat "${PI_GEN_CACHE_DIR}/stage5.key")" != "${sk}" ]]; then
    echo "=== [pi-gen-cache] Custom stage key changed (${sk}); invalidating stage5-smarttv qcow2 ==="
    rm -f "${WORK_DIR}/image-stage5-smarttv.qcow2"
    rm -rf "${WORK_DIR}/stage5-smarttv"
    echo "${sk}" > "${PI_GEN_CACHE_DIR}/stage5.key"
  fi

  if [[ -f "${WORK_DIR}/image-stage2.qcow2" ]]; then
    touch "${PI_GEN_DIR}/stage0/SKIP" "${PI_GEN_DIR}/stage1/SKIP" "${PI_GEN_DIR}/stage2/SKIP"
    echo "=== [pi-gen-cache] Using cached base image — skipping stage0, stage1, stage2 ==="
  else
    rm -f "${PI_GEN_DIR}/stage0/SKIP" "${PI_GEN_DIR}/stage1/SKIP" "${PI_GEN_DIR}/stage2/SKIP"
    echo "=== [pi-gen-cache] No cached base image — will run stage0–2 ==="
  fi

  echo "=== [pi-gen-cache] base.key=${bk} stage5.key=${sk} ==="
  df -h "${PI_GEN_CACHE_DIR}" / 2>/dev/null || df -h /
}

cmd_save() {
  [[ -d "${WORK_DIR}" ]] || {
    echo "=== [pi-gen-cache] Nothing to save (${WORK_DIR} missing) ==="
    return 0
  }

  if [[ "${PI_GEN_CACHE_FORCE_SAVE:-0}" != "1" ]]; then
    if ! find "${PI_GEN_DIR}/deploy" -maxdepth 1 -name '*.img' -print -quit 2>/dev/null | grep -q .; then
      echo "=== [pi-gen-cache] Skipping cache save (no .img in deploy — build did not finish export) ==="
      return 0
    fi
  fi

  if ! validate_work_qcow2 "${WORK_DIR}"; then
    echo "=== [pi-gen-cache] Skipping cache save (qcow2 chain failed qemu-img check) ==="
    return 0
  fi

  echo "=== [pi-gen-cache] Saving work tree to ${WORK_CACHE} ==="
  mkdir -p "${WORK_CACHE}"
  rsync -aH --delete "${WORK_DIR}/" "${WORK_CACHE}/"
  echo "$(base_cache_key)" > "${PI_GEN_CACHE_DIR}/base.key"
  echo "$(stage5_cache_key)" > "${PI_GEN_CACHE_DIR}/stage5.key"
  du -sh "${WORK_CACHE}" "${PI_GEN_CACHE_DIR}" 2>/dev/null || true
  echo "=== [pi-gen-cache] Cache saved ==="
}

usage() {
  echo "Usage: $0 {clean|clone-pigen|prepare|save}" >&2
  exit 1
}

case "${1:-}" in
  clean) cmd_clean ;;
  clone-pigen) cmd_clone_pigen ;;
  prepare) cmd_prepare ;;
  save) cmd_save ;;
  *) usage ;;
esac
