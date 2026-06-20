#!/bin/bash
# Shared RetroPie helpers for pi-gen chroot builds (ARMv6 / rpi1 / Buster).

RP_SETUP_DIR="${RP_SETUP_DIR:-/opt/retropie-setup}"
RP_BINARY_BASE="https://files.retropie.org.uk/binaries/buster/rpi1"
RP_GPG_KEY="DC9D77FF8208FFC51D8F50CCF1B030906A3B0D31"

retropie_env() {
  export DEBIAN_FRONTEND=noninteractive
  export __platform=rpi1
  export __nodialog=1
  export __user=pi
  export SUDO_USER=pi
  export __has_binaries=1
  export __curl_opts="--connect-timeout 30 --max-time 300 --retry 3"
}

retropie_ensure_gpg_key() {
  gpg --list-keys "${RP_GPG_KEY}" &>/dev/null && return 0
  gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "${RP_GPG_KEY}" \
    || gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "${RP_GPG_KEY}"
}

retropie_curl() {
  local url="$1"
  local dest="$2"
  if curl --location --connect-timeout 30 --max-time 300 --fail --retry 3 \
      -o "${dest}" "${url}"; then
    return 0
  fi
  echo "WARNING: curl failed for ${url}; retrying with -k"
  curl --location --connect-timeout 30 --max-time 300 --fail --retry 3 -k \
    -o "${dest}" "${url}"
}

retropie_module_type() {
  case "$1" in
    retroarch) echo "emulators" ;;
    emulationstation|runcommand) echo "supplementary" ;;
    lr-*) echo "libretrocores" ;;
    *) return 1 ;;
  esac
}

# Download signed RetroPie binary archives directly. retropie_packages.sh often
# fails install_bin in a QEMU chroot (HEAD probe / kmsxx deps) even when the
# rpi1 Buster archives exist on files.retropie.org.uk.
retropie_install_binary() {
  local module="$1"
  local type
  type="$(retropie_module_type "${module}")" || {
    echo "WARNING: unknown RetroPie module type for ${module}"
    return 1
  }

  local url="${RP_BINARY_BASE}/${type}/${module}.tar.gz"
  local dest="/opt/retropie/${type}"
  local tmp archive asc

  tmp="$(mktemp -d)"
  archive="${tmp}/${module}.tar.gz"
  asc="${archive}.asc"

  echo "--- retropie_install_binary ${module} (${url}) ---"
  if ! retropie_curl "${url}.asc" "${asc}"; then
    echo "WARNING: missing signature for ${module}"
    rm -rf "${tmp}"
    return 1
  fi
  if ! retropie_curl "${url}" "${archive}"; then
    echo "WARNING: download failed for ${module}"
    rm -rf "${tmp}"
    return 1
  fi
  if ! gpg --verify "${asc}" "${archive}" 2>/dev/null; then
    echo "WARNING: GPG verify failed for ${module}"
    rm -rf "${tmp}"
    return 1
  fi

  mkdir -p "${dest}"
  rm -rf "${dest}/${module}"
  if ! tar -xzf "${archive}" -C "${dest}"; then
    echo "WARNING: failed to extract ${module} archive"
    rm -rf "${tmp}"
    return 1
  fi

  rm -rf "${tmp}"
  echo "Installed ${module} binary to ${dest}/${module}"
  return 0
}

retropie_configure_module() {
  local module="$1"
  echo "--- retropie_packages.sh ${module} configure ---"
  (cd "${RP_SETUP_DIR}" && ./retropie_packages.sh "${module}" configure) \
    || echo "WARNING: configure failed for ${module}"
}

retropie_install_module() {
  local module="$1"
  if retropie_install_binary "${module}"; then
    retropie_configure_module "${module}"
    return 0
  fi

  echo "WARNING: no prebuilt rpi1 binary for ${module}; attempting source build."
  (cd "${RP_SETUP_DIR}" && ./retropie_packages.sh "${module}" install_source clean) \
    || echo "WARNING: ${module} could not be installed (binary and source both failed)."
}

# runcommand has no rpi1 tarball; install_bin also pulls kmsxx (fails in chroot).
retropie_install_runcommand() {
  local md_inst="/opt/retropie/supplementary/runcommand"
  local md_data="${RP_SETUP_DIR}/scriptmodules/supplementary/runcommand"
  local cfg="/opt/retropie/configs/all/runcommand.cfg"

  echo "--- retropie_install_runcommand ---"
  apt-get install -y --no-install-recommends fbi fbset libraspberrypi-bin

  rm -rf "${md_inst}"
  mkdir -p "${md_inst}"
  cp "${md_data}/runcommand.sh" "${md_inst}/"

  install -d -o pi -g pi /opt/retropie/configs/all
  if [[ ! -f "${cfg}" ]]; then
    cat > "${cfg}" <<'EOF'
use_art = 0
disable_joystick = 0
governor = 
disable_menu = 0
image_delay = 2
legacy_joy2key = 1
EOF
    chown pi:pi "${cfg}"
  fi

  if [[ ! -f /opt/retropie/configs/all/runcommand-launch-dialog.cfg ]]; then
    dialog --create-rc /opt/retropie/configs/all/runcommand-launch-dialog.cfg 2>/dev/null || true
    chown pi:pi /opt/retropie/configs/all/runcommand-launch-dialog.cfg 2>/dev/null || true
  fi

  echo "Installed runcommand to ${md_inst}"
}

retropie_prepare_setup() {
  retropie_env
  apt-get update
  apt-get install -y --no-install-recommends \
    git dialog unzip xmlstarlet python3 python3-pyudev build-essential cmake \
    libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libsdl2-mixer-dev \
    libfreeimage-dev libfreetype6-dev libcurl4-openssl-dev rapidjson-dev \
    ca-certificates curl gpg dirmngr

  if [[ ! -d "${RP_SETUP_DIR}" ]]; then
    git clone --depth 1 https://github.com/RetroPie/RetroPie-Setup.git "${RP_SETUP_DIR}"
  fi
  chmod +x "${RP_SETUP_DIR}/retropie_packages.sh"
  retropie_ensure_gpg_key
}
