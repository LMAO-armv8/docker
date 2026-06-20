#!/bin/bash
# kodi_install_addon.sh — install Kodi 18 (Leia) add-ons into /usr/share/kodi/addons/
# with dependency recursion. Sourced by install_kodi.sh and smarttv-install-addon.

KODI_ADDON_DIR="${KODI_ADDON_DIR:-/usr/share/kodi/addons}"
LEIA_MIRROR="${LEIA_MIRROR:-http://mirrors.kodi.tv/addons/leia}"
KODI_INSTALLED_MARKERS="${KODI_INSTALLED_MARKERS:-/tmp/kodi-addon-install-markers}"
mkdir -p "${KODI_INSTALLED_MARKERS}" "${KODI_ADDON_DIR}"

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
    zip_name=$(curl -fsSL "${index_url}" 2>/dev/null \
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

  if ! curl -fsSL -o "${tmp_zip}" "${index_url}${zip_name}"; then
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
  curl -fsSL -o "${tmp_zip}" "${zip_url}"
  unzip -q -o "${tmp_zip}" -d "${tmp_extract}"
  rm -f "${tmp_zip}"
  rm -rf "${KODI_ADDON_DIR}/${addon_id}"
  cp -a "${tmp_extract}/${addon_id}" "${KODI_ADDON_DIR}/${addon_id}"
  touch "${KODI_INSTALLED_MARKERS}/${addon_id}"
  rm -rf "${tmp_extract}"
}
