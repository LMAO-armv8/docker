#!/bin/bash
# kodi_install_addon.sh — install Kodi 18 (Leia) add-ons into /usr/share/kodi/addons/
# with dependency recursion. Sourced by install_kodi.sh and smarttv-install-addon.

KODI_ADDON_DIR="${KODI_ADDON_DIR:-/usr/share/kodi/addons}"
KODI_USER_ADDON_DIR="${KODI_USER_ADDON_DIR:-}"
KODI_SAVE_PACKAGES_DIR="${KODI_SAVE_PACKAGES_DIR:-}"
LEIA_MIRROR="${LEIA_MIRROR:-http://mirrors.kodi.tv/addons/leia}"
KODI_INSTALLED_MARKERS="${KODI_INSTALLED_MARKERS:-/tmp/kodi-addon-install-markers}"
mkdir -p "${KODI_INSTALLED_MARKERS}" "${KODI_ADDON_DIR}"

kodi_sync_to_user() {
  local addon_id="$1"
  [[ -n "${KODI_USER_ADDON_DIR}" ]] || return 0
  [[ -d "${KODI_ADDON_DIR}/${addon_id}" ]] || return 0
  mkdir -p "${KODI_USER_ADDON_DIR}"
  rm -rf "${KODI_USER_ADDON_DIR}/${addon_id}"
  cp -a "${KODI_ADDON_DIR}/${addon_id}" "${KODI_USER_ADDON_DIR}/${addon_id}"
}

kodi_save_package_zip() {
  local addon_id="$1"
  local zip_path="$2"
  [[ -n "${KODI_SAVE_PACKAGES_DIR}" ]] || return 0
  [[ -f "${zip_path}" ]] || return 0
  mkdir -p "${KODI_SAVE_PACKAGES_DIR}"
  cp -f "${zip_path}" "${KODI_SAVE_PACKAGES_DIR}/$(basename "${zip_path}")"
}

# mirrors.kodi.tv redirects HTTP→HTTPS; pi-gen Buster chroots often lack a CA chain
# that validates the mirror cert. Try strict TLS first, then -k (build-time only).
kodi_curl() {
  if curl -fsSL --retry 3 --retry-delay 2 "$@"; then
    return 0
  fi
  echo "NOTE: retrying with curl -k (mirror TLS in chroot)" >&2
  curl -fsSLk --retry 3 --retry-delay 2 "$@"
}

kodi_mirror_index() {
  local index_url="$1"
  kodi_curl "${index_url}" 2>/dev/null
}

kodi_install_addon() {
  local addon_id="$1"
  local pinned_zip="${2:-}"

  if [ -z "${addon_id}" ]; then
    echo "ERROR: kodi_install_addon requires an add-on id" >&2
    return 1
  fi

  if [ -f "${KODI_INSTALLED_MARKERS}/${addon_id}" ] && [ -d "${KODI_ADDON_DIR}/${addon_id}" ]; then
    return 0
  fi

  echo "=== [kodi_install_addon] Installing ${addon_id} ==="

  local index_url="${LEIA_MIRROR}/${addon_id}/"
  local zip_name=""
  local zip_source=""
  local addon_pattern
  addon_pattern=$(echo "${addon_id}" | sed 's/\./\\./g')

  if [ -n "${pinned_zip}" ]; then
    zip_name="${pinned_zip}"
    if [ -f "${KODI_SAVE_PACKAGES_DIR}/${zip_name}" ]; then
      zip_source="${KODI_SAVE_PACKAGES_DIR}/${zip_name}"
    else
      zip_source="${index_url}${zip_name}"
    fi
  else
    shopt -s nullglob
    local local_zips=()
    if [ -n "${KODI_SAVE_PACKAGES_DIR}" ]; then
      local_zips=("${KODI_SAVE_PACKAGES_DIR}/${addon_id}-"*.zip)
    fi
    shopt -u nullglob
    if [ ${#local_zips[@]} -gt 0 ]; then
      zip_source="${local_zips[$((${#local_zips[@]} - 1))]}"
      zip_name="$(basename "${zip_source}")"
    else
      zip_name=$(kodi_mirror_index "${index_url}" \
        | grep -oE "${addon_pattern}-[0-9][^\"<>]*\\.zip" \
        | grep -viE '\+matrix|\+nexus|\+omega|\+dharma' \
        | sort -V | tail -n1 || true)
      if [ -n "${zip_name}" ]; then
        zip_source="${index_url}${zip_name}"
      fi
    fi
  fi

  if [ -z "${zip_name}" ] || [ -z "${zip_source}" ]; then
    echo "WARNING: no Leia zip found for ${addon_id}" >&2
    return 1
  fi

  local tmp_zip="/tmp/kodi-${addon_id}.zip"
  local tmp_extract="/tmp/kodi-extract-${addon_id}"
  rm -rf "${tmp_extract}"
  mkdir -p "${tmp_extract}"

  if [[ "${zip_source}" == http* ]]; then
    if ! kodi_curl -o "${tmp_zip}" "${zip_source}"; then
      echo "WARNING: failed to download ${zip_source}" >&2
      rm -rf "${tmp_extract}" "${tmp_zip}"
      return 1
    fi
  else
    cp -f "${zip_source}" "${tmp_zip}"
  fi

  unzip -q -o "${tmp_zip}" -d "${tmp_extract}"
  kodi_save_package_zip "${addon_id}" "${tmp_zip}"
  rm -f "${tmp_zip}"

  local src_dir="${tmp_extract}/${addon_id}"
  if [ ! -d "${src_dir}" ]; then
    src_dir=$(find "${tmp_extract}" -mindepth 1 -maxdepth 1 -type d | head -n1)
  fi

  if [ ! -f "${src_dir}/addon.xml" ]; then
    echo "WARNING: ${zip_name} did not contain a valid add-on tree" >&2
    rm -rf "${tmp_extract}"
    return 1
  fi

  rm -rf "${KODI_ADDON_DIR}/${addon_id}"
  cp -a "${src_dir}" "${KODI_ADDON_DIR}/${addon_id}"
  touch "${KODI_INSTALLED_MARKERS}/${addon_id}"
  kodi_sync_to_user "${addon_id}"

  local dep_ids
  dep_ids=$(grep -oE 'addon="[^"]+"' "${KODI_ADDON_DIR}/${addon_id}/addon.xml" \
    | sed 's/addon="//;s/"$//' \
    | grep -vE '^(xbmc\.|plugin\.|pvr\.|screensaver\.|visualization\.|game\.|kodi\.resource)$' \
    | grep -vE '^xbmc\.(python|gui|json|metadata|addon)$' || true)

  for dep in ${dep_ids}; do
    case "${dep}" in
      xbmc.*|kodi.*) continue ;;
    esac
    kodi_install_addon "${dep}" || true
  done

  rm -rf "${tmp_extract}"
  echo "=== [kodi_install_addon] Installed ${addon_id} from ${zip_name} ==="
  return 0
}

kodi_install_addon_from_zip_url() {
  local zip_url="$1"
  local addon_id="$2"
  local tmp_zip="/tmp/kodi-url-${addon_id}.zip"
  local tmp_extract="/tmp/kodi-extract-url-${addon_id}"
  rm -rf "${tmp_extract}" "${tmp_zip}"
  mkdir -p "${tmp_extract}"
  kodi_curl -o "${tmp_zip}" "${zip_url}"
  unzip -q -o "${tmp_zip}" -d "${tmp_extract}"
  rm -f "${tmp_zip}"
  rm -rf "${KODI_ADDON_DIR}/${addon_id}"
  cp -a "${tmp_extract}/${addon_id}" "${KODI_ADDON_DIR}/${addon_id}"
  touch "${KODI_INSTALLED_MARKERS}/${addon_id}"
  rm -rf "${tmp_extract}"
}

kodi_install_youtube_github() {
  local dir="${KODI_ADDON_DIR}/plugin.video.youtube"
  echo "=== [kodi_install_addon] Installing YouTube from GitHub (mirror fallback) ==="
  rm -rf "${dir}"
  if git clone --depth 1 --branch v6.8.25 https://github.com/anxdpanic/plugin.video.youtube.git "${dir}" 2>/dev/null; then
    :
  elif git clone --depth 1 https://github.com/anxdpanic/plugin.video.youtube.git "${dir}"; then
    :
  else
    echo "WARNING: YouTube GitHub clone failed" >&2
    return 1
  fi
  touch "${KODI_INSTALLED_MARKERS}/plugin.video.youtube"
  kodi_sync_to_user "plugin.video.youtube"
  return 0
}

AZ2_SKIN_ID="skin.arctic.zephyr.2"
AZ2_SKIN_TAG="${AZ2_SKIN_TAG:-v0.9.60-alpha1}"
AZ2_SKIN_REPO="https://github.com/jurialmunkey/skin.arctic.zephyr.2.git"

kodi_set_skin_in_guisettings() {
  local skin_id="$1"
  local file="$2"
  [[ -f "${file}" ]] || return 1
  sed -i "s|<skin>.*</skin>|<skin>${skin_id}</skin>|" "${file}"
  sed -i "s|<soundskin[^>]*>.*</soundskin>|<soundskin default=\"true\">${skin_id}</soundskin>|" \
    "${file}" 2>/dev/null || true
  sed -i "s|<setting id=\"lookandfeel.skin\"[^>]*>.*</setting>|<setting id=\"lookandfeel.skin\">${skin_id}</setting>|" \
    "${file}" 2>/dev/null || true
  sed -i "s|<setting id=\"lookandfeel.soundskin\"[^>]*>.*</setting>|<setting id=\"lookandfeel.soundskin\">${skin_id}</setting>|" \
    "${file}" 2>/dev/null || true
}

kodi_mark_az2_version() {
  local dir="$1"
  local tag="$2"
  echo "${tag}" > "${dir}/.smarttv-pinned-version"
}

kodi_az2_is_pinned() {
  local dir="$1"
  local tag="$2"
  [[ -f "${dir}/addon.xml" ]] \
    && [[ -f "${dir}/.smarttv-pinned-version" ]] \
    && grep -qxF "${tag}" "${dir}/.smarttv-pinned-version"
}

kodi_install_addon_tree() {
  local addon_id="$1"
  local src_dir="$2"
  [[ -f "${src_dir}/addon.xml" ]] || return 1
  rm -rf "${KODI_ADDON_DIR}/${addon_id}"
  cp -a "${src_dir}" "${KODI_ADDON_DIR}/${addon_id}"
  touch "${KODI_INSTALLED_MARKERS}/${addon_id}"
  kodi_sync_to_user "${addon_id}"
  return 0
}

kodi_clone_skin_github() {
  local repo="$1"
  local addon_id="$2"
  local tag="${3:-}"
  local dir="${KODI_ADDON_DIR}/${addon_id}"
  rm -rf "${dir}"
  if [[ -n "${tag}" ]]; then
    git clone --depth 1 --branch "${tag}" "${repo}" "${dir}" || return 1
    kodi_mark_az2_version "${dir}" "${tag}"
  else
    git clone --depth 1 "${repo}" "${dir}" || return 1
  fi
  touch "${KODI_INSTALLED_MARKERS}/${addon_id}"
  kodi_sync_to_user "${addon_id}"
}

kodi_install_az2_from_release_zip() {
  local tag="${1:-${AZ2_SKIN_TAG}}"
  local addon_id="${AZ2_SKIN_ID}"
  local zip_url="https://github.com/jurialmunkey/skin.arctic.zephyr.2/archive/refs/tags/${tag}.zip"
  local saved_name="${addon_id}-${tag}.zip"
  local tmp_zip="/tmp/${saved_name}"
  local tmp_extract="/tmp/kodi-extract-${addon_id}"
  local zip_source=""

  rm -rf "${tmp_extract}"
  mkdir -p "${tmp_extract}"

  if [[ -n "${KODI_SAVE_PACKAGES_DIR}" ]] && [[ -f "${KODI_SAVE_PACKAGES_DIR}/${saved_name}" ]]; then
    zip_source="${KODI_SAVE_PACKAGES_DIR}/${saved_name}"
    cp -f "${zip_source}" "${tmp_zip}"
  elif kodi_curl -o "${tmp_zip}" "${zip_url}"; then
    kodi_save_package_zip "${addon_id}" "${tmp_zip}"
    if [[ -n "${KODI_SAVE_PACKAGES_DIR}" ]]; then
      cp -f "${tmp_zip}" "${KODI_SAVE_PACKAGES_DIR}/${saved_name}"
    fi
  else
    rm -rf "${tmp_extract}" "${tmp_zip}"
    return 1
  fi

  unzip -q -o "${tmp_zip}" -d "${tmp_extract}"
  rm -f "${tmp_zip}"

  local src_dir="${tmp_extract}/${addon_id}"
  if [[ ! -d "${src_dir}" ]]; then
    src_dir=$(find "${tmp_extract}" -mindepth 1 -maxdepth 1 -type d | head -n1)
  fi
  if ! kodi_install_addon_tree "${addon_id}" "${src_dir}"; then
    rm -rf "${tmp_extract}"
    return 1
  fi
  kodi_mark_az2_version "${KODI_ADDON_DIR}/${addon_id}" "${tag}"
  kodi_sync_to_user "${addon_id}"
  rm -rf "${tmp_extract}"
  echo "=== [kodi_install_addon] Installed ${addon_id} from GitHub release ${tag} ==="
  return 0
}

kodi_install_az2_skin() {
  local tag="${1:-${AZ2_SKIN_TAG}}"
  local addon_id="${AZ2_SKIN_ID}"
  local dir="${KODI_ADDON_DIR}/${addon_id}"

  if kodi_az2_is_pinned "${dir}" "${tag}"; then
    kodi_sync_to_user "${addon_id}"
    return 0
  fi

  echo "=== [kodi_install_addon] Installing ${addon_id} (${tag}) ==="

  if kodi_install_addon "${addon_id}"; then
    kodi_mark_az2_version "${KODI_ADDON_DIR}/${addon_id}" "${tag}"
    kodi_sync_to_user "${addon_id}"
    return 0
  fi

  if kodi_install_az2_from_release_zip "${tag}"; then
    return 0
  fi

  echo "=== [kodi_install_addon] AZ2 release zip failed; cloning GitHub tag ${tag} ==="
  kodi_clone_skin_github "${AZ2_SKIN_REPO}" "${addon_id}" "${tag}"
}
