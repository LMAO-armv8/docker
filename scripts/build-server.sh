#!/bin/bash
# build-server.sh — same pi-gen pipeline as GitHub Actions, for a Linux cloud VM.
#
# Requirements: Ubuntu 22.04, sudo, ~50GB free disk, git clone of this repo.
#
# Usage:
#   cd /path/to/raspi-smarttv-retro
#   chmod +x scripts/build-server.sh
#   ./scripts/build-server.sh
#   PUBLISH_RELEASE=1 ./scripts/build-server.sh
#
# Optional env:
#   IMG_NAME=smarttv-retro-pi1
#   PI_GEN_BRANCH=buster
#   PI_GEN_RELEASE=buster
#   GITHUB_REPO=owner/raspi-smarttv-retro
#   BUILD_TAG=build-server-20250621-1430
#   SKIP_APT_HOST=1
#   KEEP_PI_GEN=1

set -euo pipefail

IMG_NAME="${IMG_NAME:-smarttv-retro-pi1}"
PI_GEN_BRANCH="${PI_GEN_BRANCH:-buster}"
PI_GEN_RELEASE="${PI_GEN_RELEASE:-buster}"
PUBLISH_RELEASE="${PUBLISH_RELEASE:-0}"
BUILD_TAG="${BUILD_TAG:-build-server-$(date +%Y%m%d-%H%M%S)}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

echo "=== Smart TV Retro server build ==="
echo "Repo:    ${REPO_ROOT}"
echo "Image:   ${IMG_NAME}.img.gz"
echo "pi-gen:  ${PI_GEN_BRANCH}"
echo "Release: ${PUBLISH_RELEASE} (set PUBLISH_RELEASE=1 to upload to GitHub)"
df -h /

if [[ "$(id -u)" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
  echo "ERROR: run as root or configure passwordless sudo." >&2
  exit 1
fi

run() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# --- Host dependencies (same as .github/workflows/build.yml) ---------------
if [[ "${SKIP_APT_HOST:-0}" != "1" ]]; then
  run apt-get update
  run apt-get install -y --no-install-recommends \
    coreutils quilt parted qemu-user-static binfmt-support debootstrap \
    zerofree zip dosfstools libarchive-tools libcap2-bin grep rsync \
    xz-utils file xxd kmod git curl bc qemu-utils kpartx gpg pigz \
    python3 ca-certificates
  run update-binfmts --enable qemu-arm
fi

# --- pi-gen checkout -------------------------------------------------------
if [[ "${KEEP_PI_GEN:-0}" != "1" ]] || [[ ! -d pi-gen/.git ]]; then
  rm -rf pi-gen
  git clone --depth 1 --branch "${PI_GEN_BRANCH}" \
    https://github.com/RPi-Distro/pi-gen.git pi-gen
fi

# --- Patch pi-gen (identical to build.yml) ---------------------------------
sed -i 's|http://raspbian.raspberrypi.org/raspbian/|https://legacy.raspbian.org/raspbian/|g' \
  pi-gen/stage0/prerun.sh \
  pi-gen/stage0/00-configure-apt/files/sources.list

sed -i 's|backing_file=\${WORK_DIR}/image-\${PREV_STAGE}\.qcow2|backing_file=${WORK_DIR}/image-${PREV_STAGE}.qcow2,backing_fmt=qcow2|' \
  pi-gen/scripts/qcow2_handling
sed -i 's|qemu-img rebase -f qcow2 -u -b \${PREV_IMG}\.qcow2|qemu-img rebase -f qcow2 -u -b ${PREV_IMG}.qcow2 -F qcow2|' \
  pi-gen/build.sh
sed -i 's|qemu-nbd --discard=unmap -c $NBD_DEV|qemu-nbd -f qcow2 --discard=unmap -c $NBD_DEV|' \
  pi-gen/scripts/qcow2_handling

cat > pi-gen/stage0/00-configure-apt/files/80-archive-retries <<'EOF'
Acquire::Retries "10";
Acquire::https::Timeout "120";
Acquire::http::Timeout "120";
Acquire::Check-Valid-Until "false";
EOF
sed -i '/install -m 644 files\/raspi.list/a install -m 644 files/80-archive-retries "${ROOTFS_DIR}/etc/apt/apt.conf.d/80-archive-retries"' \
  pi-gen/stage0/00-configure-apt/00-run.sh

cat > pi-gen/stage0/00-configure-apt/files/policy-rc.d <<'EOF'
#!/bin/sh
exit 101
EOF
chmod +x pi-gen/stage0/00-configure-apt/files/policy-rc.d
sed -i '/install -m 644 files\/raspi.list/a install -d "${ROOTFS_DIR}/usr/sbin"' \
  pi-gen/stage0/00-configure-apt/00-run.sh
sed -i '/install -d "\${ROOTFS_DIR}\/usr\/sbin"/a install -m 755 files/policy-rc.d "${ROOTFS_DIR}/usr/sbin/policy-rc.d"' \
  pi-gen/stage0/00-configure-apt/00-run.sh

python3 <<'PY'
import re
from pathlib import Path

build_sh = Path("pi-gen/build.sh")
text = build_sh.read_text()
pattern = re.compile(
    r"on_chroot << EOF\n(apt-get -o APT::Acquire::Retries=3 install(?: --no-install-recommends)? -y \$PACKAGES)\nEOF"
)

def repl(match):
    cmd = match.group(1).replace("Retries=3", "Retries=10")
    return (
        "on_chroot << EOF\n"
        "for attempt in 1 2 3 4 5; do\n"
        f"  {cmd} && break\n"
        "  [ \\$attempt -eq 5 ] && exit 1\n"
        "  sleep 20\n"
        "done\n"
        "EOF"
    )

text, count = pattern.subn(repl, text)
if count != 2:
    raise SystemExit(f"expected to patch 2 apt install hooks in pi-gen/build.sh, got {count}")
build_sh.write_text(text)
PY

# --- Custom stage ----------------------------------------------------------
rm -rf pi-gen/stage5-smarttv
cp -r pi-gen-stage pi-gen/stage5-smarttv
mkdir -p pi-gen/stage5-smarttv/00-copy-files/files
cp -r scripts pi-gen/stage5-smarttv/00-copy-files/files/
cp -r config pi-gen/stage5-smarttv/00-copy-files/files/
cp -r addons pi-gen/stage5-smarttv/00-copy-files/files/ 2>/dev/null || true
find pi-gen/stage5-smarttv -name "*.sh" -exec chmod +x {} \;
chmod +x scripts/*.sh
touch pi-gen/stage3/SKIP pi-gen/stage4/SKIP
touch pi-gen/stage2/SKIP_IMAGES

# --- pi-gen config ---------------------------------------------------------
cat > pi-gen/config <<EOF
IMG_NAME=${IMG_NAME}
RELEASE=${PI_GEN_RELEASE}
DEPLOY_COMPRESSION=none
LOCALE_DEFAULT=en_GB.UTF-8
TARGET_HOSTNAME=smarttv-retropi
KEYBOARD_KEYMAP=us
KEYBOARD_LAYOUT="English (US)"
TIMEZONE_DEFAULT=Etc/UTC
FIRST_USER_NAME=pi
FIRST_USER_PASS=raspberry
ENABLE_SSH=1
PUBKEY_SSH_FIRST_USER=
STAGE_LIST="stage0 stage1 stage2 stage5-smarttv"
EOF

# --- Build -----------------------------------------------------------------
run modprobe nbd max_part=16
cd pi-gen
chmod +x build.sh
run ./build.sh
cd "${REPO_ROOT}"

IMG_FILE="$(find pi-gen/deploy -maxdepth 1 -iname '*.img' | head -n1)"
if [[ -z "${IMG_FILE}" ]]; then
  echo "ERROR: no .img in pi-gen/deploy" >&2
  exit 1
fi
ls -lh "${IMG_FILE}"

gzip -9 -c "${IMG_FILE}" > "${IMG_NAME}.img.gz"
ls -lh "${IMG_NAME}.img.gz"

echo "=== Build complete: ${REPO_ROOT}/${IMG_NAME}.img.gz ==="

# --- GitHub Release (same output as action-gh-release in build.yml) ---------
if [[ "${PUBLISH_RELEASE}" == "1" ]]; then
  if ! command -v gh >/dev/null; then
    run apt-get install -y gh
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh is not authenticated. Run: gh auth login" >&2
    exit 1
  fi

  if [[ -n "${GITHUB_REPO:-}" ]]; then
    REPO="${GITHUB_REPO}"
  else
    REPO="$(git remote get-url origin | sed -E 's|.*github.com[:/](.+/.+)(\.git)?|\1|')"
  fi

  gh release create "${BUILD_TAG}" \
    --repo "${REPO}" \
    --title "Smart TV / Retro Pi 1 image - ${BUILD_TAG}" \
    --notes "Server build of the Smart TV + Retro Gaming image for Raspberry Pi 1 Model B/B+.

Flash \`${IMG_NAME}.img.gz\` with Raspberry Pi Imager, balenaEtcher, or \`dd\` (see README.md for full instructions).

Default login: user \`pi\`, password \`raspberry\`. Change this on first boot." \
    "${IMG_NAME}.img.gz"

  echo "=== Published: https://github.com/${REPO}/releases/tag/${BUILD_TAG} ==="
fi
