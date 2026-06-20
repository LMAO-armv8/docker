#!/bin/bash
# kodi_install_addon.sh — install Kodi 18 (Leia) add-ons into /usr/share/kodi/addons/
# with dependency recursion. Sourced by install_kodi.sh and smarttv-install-addon.

KODI_ADDON_DIR="${KODI_ADDON_DIR:-/usr/share/kodi/addons}"
LEIA_MIRROR="${LEIA_MIRROR:-http://mirrors.kodi.tv/addons/leia}"
KODI_INSTALLED_MARKERS="${KODI_INSTALLED_MARKERS:-/tmp/kodi-addon-install-markers}"
mkdir -p "${KODI_INSTALLED_MARKERS}" "${KODI_ADDON_DIR}"

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
  local addon_pattern
  addon_pattern=$(echo "${addon_id}" | sed 's/\./\\./g')

  if [ -n "${pinned_zip}" ]; then
    zip_name="${pinned_zip}"
  else
    zip_name=$(kodi_mirror_index "${index_url}" \
      | grep -oE "${addon_pattern}-[0-9][^\"<>]*\\.zip" \
      | grep -viE '\+matrix|\+nexus|\+omega|\+dharma' \
      | sort -V | tail -n1 || true)
  fi

  if [ -z "${zip_name}" ]; then
    echo "WARNING: no Leia zip found for ${addon_id} at ${index_url}" >&2
    return 1
  fi

  local tmp_zip="/tmp/kodi-${addon_id}.zip"
  local tmp_extract="/tmp/kodi-extract-${addon_id}"
  rm -rf "${tmp_extract}"
  mkdir -p "${tmp_extract}"

  if ! kodi_curl -o "${tmp_zip}" "${index_url}${zip_name}"; then
    echo "WARNING: failed to download ${index_url}${zip_name}" >&2
    rm -rf "${tmp_extract}" "${tmp_zip}"
    return 1
  fi

  unzip -q -o "${tmp_zip}" -d "${tmp_extract}"
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
  return 0
}

kodi_clone_skin_github() {
  local repo="$1"
  local addon_id="$2"
  local dir="${KODI_ADDON_DIR}/${addon_id}"
  rm -rf "${dir}"
  git clone --depth 1 "${repo}" "${dir}" || return 1
  touch "${KODI_INSTALLED_MARKERS}/${addon_id}"
}
