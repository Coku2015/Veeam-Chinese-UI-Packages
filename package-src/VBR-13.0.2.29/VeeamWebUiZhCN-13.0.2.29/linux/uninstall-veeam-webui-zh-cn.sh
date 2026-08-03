#!/usr/bin/env bash
set -euo pipefail

BUILD="13.0.2.29"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

sha256_file() {
  sha256sum "$1" | awk '{print tolower($1)}'
}

TEST_MODE="${VEEAM_ZH_CN_TEST_MODE:-0}"
if [[ "${EUID}" -ne 0 && "${TEST_MODE}" != "1" ]]; then
  die "Run this script as root: sudo ./uninstall-veeam-webui-zh-cn.sh"
fi

if [[ "${TEST_MODE}" == "1" ]]; then
  BACKUP_ROOT="${VEEAM_ZH_CN_TEST_BACKUP_ROOT:?Set VEEAM_ZH_CN_TEST_BACKUP_ROOT in test mode}"
else
  BACKUP_ROOT="/var/lib/veeam-webui-zh-cn/${BUILD}"
fi
MANIFEST_PATH="${BACKUP_ROOT}/manifest.env"

command -v sha256sum >/dev/null 2>&1 || die "Required command not found: sha256sum"
command -v awk >/dev/null 2>&1 || die "Required command not found: awk"
[[ -f "${MANIFEST_PATH}" ]] || die "Package manifest was not found: ${MANIFEST_PATH}"

# shellcheck disable=SC1090
source "${MANIFEST_PATH}"

for path in \
  "${HTML_PATH}" \
  "${INDEX_PATH}" \
  "${PLUGIN_PATH}" \
  "${LOGIN_SELECTOR_PATH}" \
  "${BACKUP_HTML_PATH}" \
  "${BACKUP_INDEX_PATH}" \
  "${BACKUP_PLUGIN_PATH}" \
  "${BACKUP_LOGIN_SELECTOR_PATH}"; do
  [[ -f "${path}" ]] || die "Required current or backup file was not found: ${path}"
done

[[ "$(sha256_file "${HTML_PATH}")" == "${PATCHED_HTML_SHA256}" ]] || die "Current index.html was not written by this package. No changes were made."
[[ "$(sha256_file "${INDEX_PATH}")" == "${PATCHED_INDEX_SHA256}" ]] || die "Current main bundle was not written by this package. No changes were made."
[[ "$(sha256_file "${PLUGIN_PATH}")" == "${PATCHED_PLUGIN_SHA256}" ]] || die "Current plugin bundle was not written by this package. No changes were made."
[[ "$(sha256_file "${LOGIN_SELECTOR_PATH}")" == "${PATCHED_LOGIN_SELECTOR_SHA256}" ]] || die "Current login selector was not written by this package. No changes were made."

if [[ -f "${NATIVE_ASSET_PATH}" ]]; then
  [[ "$(sha256_file "${NATIVE_ASSET_PATH}")" == "${NATIVE_ASSET_SHA256}" ]] || die "Current native Chinese asset was not written by this package. No changes were made."
fi
if [[ -f "${CATALOG_ASSET_PATH}" ]]; then
  [[ "$(sha256_file "${CATALOG_ASSET_PATH}")" == "${CATALOG_ASSET_SHA256}" ]] || die "Current Chinese catalog was not written by this package. No changes were made."
fi

TMP_HTML="${HTML_PATH}.veeam-zh-cn-restore.$$"
TMP_INDEX="${INDEX_PATH}.veeam-zh-cn-restore.$$"
TMP_PLUGIN="${PLUGIN_PATH}.veeam-zh-cn-restore.$$"
TMP_LOGIN_SELECTOR="${LOGIN_SELECTOR_PATH}.veeam-zh-cn-restore.$$"
cleanup() {
  rm -f "${TMP_HTML}" "${TMP_INDEX}" "${TMP_PLUGIN}" "${TMP_LOGIN_SELECTOR}"
}
trap cleanup EXIT

cp -p "${BACKUP_HTML_PATH}" "${TMP_HTML}"
cp -p "${BACKUP_INDEX_PATH}" "${TMP_INDEX}"
cp -p "${BACKUP_PLUGIN_PATH}" "${TMP_PLUGIN}"
cp -p "${BACKUP_LOGIN_SELECTOR_PATH}" "${TMP_LOGIN_SELECTOR}"

mv -f "${TMP_HTML}" "${HTML_PATH}"
mv -f "${TMP_INDEX}" "${INDEX_PATH}"
mv -f "${TMP_PLUGIN}" "${PLUGIN_PATH}"
mv -f "${TMP_LOGIN_SELECTOR}" "${LOGIN_SELECTOR_PATH}"
rm -f "${NATIVE_ASSET_PATH}" "${CATALOG_ASSET_PATH}"
trap - EXIT

[[ "$(sha256_file "${HTML_PATH}")" == "${ORIGINAL_HTML_SHA256}" ]] || die "Restored index.html hash is unexpected. Keep the backup directory: ${BACKUP_ROOT}"
[[ "$(sha256_file "${INDEX_PATH}")" == "${ORIGINAL_INDEX_SHA256}" ]] || die "Restored main bundle hash is unexpected. Keep the backup directory: ${BACKUP_ROOT}"
[[ "$(sha256_file "${PLUGIN_PATH}")" == "${ORIGINAL_PLUGIN_SHA256}" ]] || die "Restored plugin bundle hash is unexpected. Keep the backup directory: ${BACKUP_ROOT}"
[[ "$(sha256_file "${LOGIN_SELECTOR_PATH}")" == "${ORIGINAL_LOGIN_SELECTOR_SHA256}" ]] || die "Restored login selector hash is unexpected. Keep the backup directory: ${BACKUP_ROOT}"

rm -rf "${BACKUP_ROOT}"
echo "Veeam Web UI Simplified Chinese package uninstalled. Original file hashes were verified."
