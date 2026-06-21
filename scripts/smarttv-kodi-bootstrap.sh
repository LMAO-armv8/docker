#!/bin/bash
# smarttv-kodi-bootstrap.sh — ensure Kodi skin/add-ons/config exist before UI starts.
# Runs on every boot until the stack is healthy (offline packages first, then network).

set -euo pipefail

TARGET_USER="${TARGET_USER:-pi}"
TARGET_HOME="/home/${TARGET_USER}"
KODI_HOME="${TARGET_HOME}/.kodi"
KODI_SYS_ADDONS="/usr/share/kodi/addons"
KODI_USER_ADDONS="${KODI_HOME}/addons"
KODI_PACKAGES="/usr/local/share/smarttv/addon-packages"
KODI_CONFIG_SRC="/usr/local/share/smarttv/kodi-config"
LOG="/var/log/smarttv-kodi-bootstrap.log"
STATE="/var/lib/smarttv/kodi-bootstrap-ok"
AZ2_SKIN_ID="skin.arctic.zephyr.2"
AZ2_SKIN_TAG="v0.9.60-alpha1"
AZ2_SKIN_REPO="https://github.com/jurialmunkey/skin.arctic.zephyr.2.git"

mkdir -p "${KODI_USER_ADDONS}" "${KODI_HOME}/userdata" /var/lib/smarttv
chown -R "${TARGET_USER}:${TARGET_USER}" "${KODI_HOME}"

log() {
  echo "[$(date -Is)] $*" | tee -a "${LOG}"
}

install_from_saved_zip() {
  local addon_id="$1"
  local zip=""
  shopt -s nullglob
  local zips=("${KODI_PACKAGES}/${addon_id}-"*.zip)
  shopt -u nullglob
  [[ ${#zips[@]} -gt 0 ]] || return 1
  zip="${zips[$((${#zips[@]} - 1))]}"
  local tmp="/tmp/kodi-bootstrap-${addon_id}"
  rm -rf "${tmp}"
  mkdir -p "${tmp}"
  unzip -q -o "${zip}" -d "${tmp}"
  local src="${tmp}/${addon_id}"
  [[ -d "${src}" ]] || src="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [[ -f "${src}/addon.xml" ]] || return 1
  rm -rf "${KODI_SYS_ADDONS}/${addon_id}" "${KODI_USER_ADDONS}/${addon_id}"
  cp -a "${src}" "${KODI_SYS_ADDONS}/${addon_id}"
  cp -a "${src}" "${KODI_USER_ADDONS}/${addon_id}"
  if [[ "${addon_id}" == "${AZ2_SKIN_ID}" ]]; then
    echo "${AZ2_SKIN_TAG}" > "${KODI_SYS_ADDONS}/${addon_id}/.smarttv-pinned-version"
    cp -f "${KODI_SYS_ADDONS}/${addon_id}/.smarttv-pinned-version" \
      "${KODI_USER_ADDONS}/${addon_id}/.smarttv-pinned-version"
  fi
  rm -rf "${tmp}"
  log "Installed ${addon_id} from ${zip}"
  return 0
}

install_from_github() {
  local repo="$1"
  local addon_id="$2"
  local tag="${3:-}"
  local dir="${KODI_SYS_ADDONS}/${addon_id}"
  rm -rf "${dir}"
  if [[ -n "${tag}" ]]; then
    git clone --depth 1 --branch "${tag}" "${repo}" "${dir}" || return 1
    echo "${tag}" > "${dir}/.smarttv-pinned-version"
  else
    git clone --depth 1 "${repo}" "${dir}" || return 1
  fi
  cp -a "${dir}" "${KODI_USER_ADDONS}/${addon_id}"
  log "Installed ${addon_id} from ${repo}${tag:+ @ ${tag}}"
  return 0
}

install_with_network() {
  local addon_id="$1"
  # shellcheck source=/dev/null
  source /usr/local/share/smarttv/kodi_install_addon.sh
  export KODI_ADDON_DIR="${KODI_SYS_ADDONS}"
  export KODI_USER_ADDON_DIR="${KODI_USER_ADDONS}"
  export KODI_SAVE_PACKAGES_DIR="${KODI_PACKAGES}"
  if [[ "${addon_id}" == "${AZ2_SKIN_ID}" ]]; then
    if kodi_install_az2_skin "${AZ2_SKIN_TAG}"; then
      return 0
    fi
    return 1
  fi
  if kodi_install_addon "${addon_id}"; then
    cp -a "${KODI_SYS_ADDONS}/${addon_id}" "${KODI_USER_ADDONS}/${addon_id}" 2>/dev/null || true
    return 0
  fi
  return 1
}

az2_is_pinned() {
  local dir="$1"
  [[ -f "${dir}/addon.xml" ]] \
    && [[ -f "${dir}/.smarttv-pinned-version" ]] \
    && grep -qxF "${AZ2_SKIN_TAG}" "${dir}/.smarttv-pinned-version"
}

ensure_az2_skin() {
  if az2_is_pinned "${KODI_SYS_ADDONS}/${AZ2_SKIN_ID}" \
    || az2_is_pinned "${KODI_USER_ADDONS}/${AZ2_SKIN_ID}"; then
    return 0
  fi
  install_from_saved_zip "${AZ2_SKIN_ID}" && return 0
  install_with_network "${AZ2_SKIN_ID}" && return 0
  install_from_github "${AZ2_SKIN_REPO}" "${AZ2_SKIN_ID}" "${AZ2_SKIN_TAG}" && return 0
  return 1
}

ensure_addon() {
  local addon_id="$1"
  if [[ "${addon_id}" == "${AZ2_SKIN_ID}" ]]; then
    ensure_az2_skin && return 0
    return 1
  fi
  if [[ -f "${KODI_SYS_ADDONS}/${addon_id}/addon.xml" ]] \
    || [[ -f "${KODI_USER_ADDONS}/${addon_id}/addon.xml" ]]; then
    return 0
  fi
  install_from_saved_zip "${addon_id}" && return 0
  install_with_network "${addon_id}" && return 0
  return 1
}

apply_kodi_config() {
  local skin_id="$1"
  [[ -d "${KODI_CONFIG_SRC}" ]] || return 0
  for f in guisettings.xml advancedsettings.xml sources.xml favourites.xml; do
    [[ -f "${KODI_CONFIG_SRC}/${f}" ]] || continue
    cp "${KODI_CONFIG_SRC}/${f}" "${KODI_HOME}/userdata/${f}"
  done
  if [[ -f "${KODI_HOME}/userdata/guisettings.xml" ]]; then
    # shellcheck source=/dev/null
    source /usr/local/share/smarttv/kodi_install_addon.sh
    kodi_set_skin_in_guisettings "${skin_id}" "${KODI_HOME}/userdata/guisettings.xml"
  fi
  chown -R "${TARGET_USER}:${TARGET_USER}" "${KODI_HOME}"
  log "Applied Kodi userdata (skin=${skin_id})"
}

guisettings_skin() {
  local file="${KODI_HOME}/userdata/guisettings.xml"
  [[ -f "${file}" ]] || return 0
  if grep -q '<skin>' "${file}" 2>/dev/null; then
    sed -n 's|.*<skin>\([^<]*\)</skin>.*|\1|p' "${file}" | head -n1
    return 0
  fi
  sed -n 's|.*<setting id="lookandfeel.skin"[^>]*>\([^<]*\)</setting>.*|\1|p' "${file}" | head -n1
}

AZ2_DEPS=(
  script.module.requests
  script.module.simplejson
  script.skinshortcuts
  script.image.resource.select
  plugin.program.autocompletion
  resource.images.studios.white
  resource.images.moviegenreicons.transparent
  resource.images.weathericons.outline-hd
)
YT_DEPS=(
  script.module.six
  script.module.unidecode
  script.module.youtube.dl
  script.module.inputstreamhelper
)

main() {
  if [[ -f "${STATE}" ]]; then
    exit 0
  fi

  log "=== Smart TV Kodi bootstrap start ==="

  for dep in "${AZ2_DEPS[@]}" "${YT_DEPS[@]}"; do
    ensure_addon "${dep}" || log "WARNING: optional dep missing: ${dep}"
  done

  SKIN="${AZ2_SKIN_ID}"
  if ! ensure_az2_skin; then
    log "AZ2 install failed; falling back to Estuary"
    SKIN="skin.estuary"
  fi

  for dep in "${YT_DEPS[@]}"; do
    ensure_addon "${dep}" || true
  done

  if ! ensure_addon "plugin.video.youtube"; then
    install_from_github "https://github.com/anxdpanic/plugin.video.youtube.git" "plugin.video.youtube" \
      || log "WARNING: YouTube add-on missing"
  fi

  ensure_addon "plugin.program.smarttvstore" || {
    if [[ -d /usr/local/share/smarttv/plugin.program.smarttvstore ]]; then
      cp -a /usr/local/share/smarttv/plugin.program.smarttvstore \
        "${KODI_SYS_ADDONS}/plugin.program.smarttvstore"
      cp -a /usr/local/share/smarttv/plugin.program.smarttvstore \
        "${KODI_USER_ADDONS}/plugin.program.smarttvstore"
    fi
  }

  apply_kodi_config "${SKIN}"

  chmod -R a+rX "${KODI_SYS_ADDONS}" "${KODI_USER_ADDONS}" 2>/dev/null || true
  chown -R "${TARGET_USER}:${TARGET_USER}" "${KODI_HOME}"

  local ok=1
  for id in plugin.program.smarttvstore plugin.video.youtube; do
    if [[ ! -f "${KODI_SYS_ADDONS}/${id}/addon.xml" ]] \
      && [[ ! -f "${KODI_USER_ADDONS}/${id}/addon.xml" ]]; then
      log "MISSING after bootstrap: ${id}"
      ok=0
    else
      log "OK: ${id}"
    fi
  done

  if [[ "${SKIN}" == "${AZ2_SKIN_ID}" ]]; then
    if [[ ! -f "${KODI_SYS_ADDONS}/${SKIN}/addon.xml" ]] \
      && [[ ! -f "${KODI_USER_ADDONS}/${SKIN}/addon.xml" ]]; then
      log "MISSING after bootstrap: ${SKIN}"
      ok=0
    else
      log "OK: ${SKIN} (${AZ2_SKIN_TAG})"
    fi
    local active_skin
    active_skin="$(guisettings_skin || true)"
    if [[ "${active_skin}" == "skin.estuary" ]]; then
      log "WARNING: guisettings still set to Estuary after apply"
      ok=0
    fi
  fi

  if [[ "${ok}" -eq 1 ]] && [[ "${SKIN}" != "skin.estuary" ]]; then
    touch "${STATE}"
    log "=== Kodi bootstrap complete ==="
  else
    log "=== Kodi bootstrap incomplete (will retry next boot) ==="
    exit 0
  fi
}

main "$@"
