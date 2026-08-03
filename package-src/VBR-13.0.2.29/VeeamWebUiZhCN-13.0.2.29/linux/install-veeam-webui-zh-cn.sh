#!/usr/bin/env bash
set -euo pipefail

BUILD="13.0.2.29"
EXPECTED_HTML_SHA256="7d5d30326a648dea90e1fa16f818e1d46c9d5bb2ea596131b273b4a246bba7e8"
EXPECTED_INDEX_SHA256="a56354fa06e4857d87ddb50b29ab53702896a85334ec0a20bfa4103ca53324bb"
EXPECTED_PLUGIN_SHA256="e1af0c38752ae7669a577bfa70e8119b80d0ac906bdb3548ed76a21c83ab8ec2"
EXPECTED_LOGIN_SELECTOR_SHA256="ae389601d582ea5ea6ca20bb77204493b77837ee79e5ba4166f2fe00fcec078d"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

sha256_file() {
  sha256sum "$1" | awk '{print tolower($1)}'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

TEST_MODE="${VEEAM_ZH_CN_TEST_MODE:-0}"
if [[ "${EUID}" -ne 0 && "${TEST_MODE}" != "1" ]]; then
  die "Run this script as root: sudo ./install-veeam-webui-zh-cn.sh"
fi

require_command sha256sum
require_command awk
require_command python3

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WEB_ROOT="${WEB_ROOT:-/opt/veeam/vbr/GatewayApiService/app}"
HTML_PATH="${WEB_ROOT}/index.html"
ASSETS_DIR="${WEB_ROOT}/assets"
INDEX_PATH="${ASSETS_DIR}/index-e21aa407.js"
PLUGIN_PATH="${WEB_ROOT}/plugin/plugin.js"
LOGIN_SELECTOR_PATH="${LOGIN_SELECTOR_PATH:-/opt/veeam/vbr/wwwroot/oauth/static/lib/languageSelector.js}"
NATIVE_ASSET_PATH="${ASSETS_DIR}/veeam-zh-CN-native.js"
CATALOG_ASSET_PATH="${ASSETS_DIR}/veeam-zh-CN-catalog.js"
SOURCE_NATIVE_ASSET_PATH="${SCRIPT_DIR}/assets/veeam-zh-CN-native.js"
SOURCE_CATALOG_ASSET_PATH="${SCRIPT_DIR}/assets/veeam-zh-CN-catalog.js"

if [[ "${TEST_MODE}" == "1" ]]; then
  BACKUP_ROOT="${VEEAM_ZH_CN_TEST_BACKUP_ROOT:?Set VEEAM_ZH_CN_TEST_BACKUP_ROOT in test mode}"
else
  BACKUP_ROOT="/var/lib/veeam-webui-zh-cn/${BUILD}"
fi
BACKUP_HTML_PATH="${BACKUP_ROOT}/index.html.original"
BACKUP_INDEX_PATH="${BACKUP_ROOT}/index-e21aa407.js.original"
BACKUP_PLUGIN_PATH="${BACKUP_ROOT}/plugin.js.original"
BACKUP_LOGIN_SELECTOR_PATH="${BACKUP_ROOT}/languageSelector.js.original"
MANIFEST_PATH="${BACKUP_ROOT}/manifest.env"

[[ -f "${HTML_PATH}" ]] || die "index.html was not found: ${HTML_PATH}"
[[ -f "${INDEX_PATH}" ]] || die "Main Web UI bundle was not found: ${INDEX_PATH}"
[[ -f "${PLUGIN_PATH}" ]] || die "Web UI plugin bundle was not found: ${PLUGIN_PATH}"
[[ -f "${LOGIN_SELECTOR_PATH}" ]] || die "OAuth login language selector was not found: ${LOGIN_SELECTOR_PATH}"
[[ -f "${SOURCE_NATIVE_ASSET_PATH}" ]] || die "Package asset is missing: ${SOURCE_NATIVE_ASSET_PATH}"
[[ -f "${SOURCE_CATALOG_ASSET_PATH}" ]] || die "Package asset is missing: ${SOURCE_CATALOG_ASSET_PATH}"

HTML_SHA256="$(sha256_file "${HTML_PATH}")"
INDEX_SHA256="$(sha256_file "${INDEX_PATH}")"
PLUGIN_SHA256="$(sha256_file "${PLUGIN_PATH}")"
LOGIN_SELECTOR_SHA256="$(sha256_file "${LOGIN_SELECTOR_PATH}")"
SOURCE_NATIVE_SHA256="$(sha256_file "${SOURCE_NATIVE_ASSET_PATH}")"
SOURCE_CATALOG_SHA256="$(sha256_file "${SOURCE_CATALOG_ASSET_PATH}")"

if [[ -f "${MANIFEST_PATH}" ]]; then
  # shellcheck disable=SC1090
  source "${MANIFEST_PATH}"
  ASSETS_MATCH="no"
  if [[ -f "${NATIVE_ASSET_PATH}" && -f "${CATALOG_ASSET_PATH}" ]] &&
     [[ "$(sha256_file "${NATIVE_ASSET_PATH}")" == "${NATIVE_ASSET_SHA256}" ]] &&
     [[ "$(sha256_file "${CATALOG_ASSET_PATH}")" == "${CATALOG_ASSET_SHA256}" ]]; then
    ASSETS_MATCH="yes"
  fi
  if [[ "${HTML_SHA256}" == "${PATCHED_HTML_SHA256}" &&
        "${INDEX_SHA256}" == "${PATCHED_INDEX_SHA256}" &&
        "${PLUGIN_SHA256}" == "${PATCHED_PLUGIN_SHA256}" &&
        "${LOGIN_SELECTOR_SHA256}" == "${PATCHED_LOGIN_SELECTOR_SHA256}" &&
        "${ASSETS_MATCH}" == "yes" ]]; then
    echo "Veeam Web UI Simplified Chinese package is already installed. No changes were made."
    exit 0
  fi
  die "An existing manifest was found, but current Web UI files do not match it. No changes were made."
fi

if [[ "${HTML_SHA256}" != "${EXPECTED_HTML_SHA256}" ||
      "${INDEX_SHA256}" != "${EXPECTED_INDEX_SHA256}" ||
      "${PLUGIN_SHA256}" != "${EXPECTED_PLUGIN_SHA256}" ||
      "${LOGIN_SELECTOR_SHA256}" != "${EXPECTED_LOGIN_SELECTOR_SHA256}" ]]; then
  die "Current Web UI hashes do not match VBR ${BUILD}. No changes were made."
fi

if [[ -f "${NATIVE_ASSET_PATH}" && "$(sha256_file "${NATIVE_ASSET_PATH}")" != "${SOURCE_NATIVE_SHA256}" ]]; then
  die "A different native Chinese asset already exists: ${NATIVE_ASSET_PATH}"
fi
if [[ -f "${CATALOG_ASSET_PATH}" && "$(sha256_file "${CATALOG_ASSET_PATH}")" != "${SOURCE_CATALOG_SHA256}" ]]; then
  die "A different Chinese catalog asset already exists: ${CATALOG_ASSET_PATH}"
fi

mkdir -p "${BACKUP_ROOT}"
cp -p "${HTML_PATH}" "${BACKUP_HTML_PATH}"
cp -p "${INDEX_PATH}" "${BACKUP_INDEX_PATH}"
cp -p "${PLUGIN_PATH}" "${BACKUP_PLUGIN_PATH}"
cp -p "${LOGIN_SELECTOR_PATH}" "${BACKUP_LOGIN_SELECTOR_PATH}"

TMP_HTML="${HTML_PATH}.veeam-zh-cn-new.$$"
TMP_INDEX="${INDEX_PATH}.veeam-zh-cn-new.$$"
TMP_PLUGIN="${PLUGIN_PATH}.veeam-zh-cn-new.$$"
TMP_LOGIN_SELECTOR="${LOGIN_SELECTOR_PATH}.veeam-zh-cn-new.$$"
ROLLBACK_ON_ERROR="yes"

cleanup() {
  status=$?
  set +e
  rm -f "${TMP_HTML}" "${TMP_INDEX}" "${TMP_PLUGIN}" "${TMP_LOGIN_SELECTOR}"
  if [[ "${status}" -ne 0 && "${ROLLBACK_ON_ERROR}" == "yes" ]]; then
    cp -p "${BACKUP_HTML_PATH}" "${HTML_PATH}"
    cp -p "${BACKUP_INDEX_PATH}" "${INDEX_PATH}"
    cp -p "${BACKUP_PLUGIN_PATH}" "${PLUGIN_PATH}"
    cp -p "${BACKUP_LOGIN_SELECTOR_PATH}" "${LOGIN_SELECTOR_PATH}"
    rm -f "${NATIVE_ASSET_PATH}" "${CATALOG_ASSET_PATH}" "${MANIFEST_PATH}"
    echo "Installation failed; original Web UI files were restored." >&2
  fi
  exit "${status}"
}
trap cleanup EXIT

python3 - "${HTML_PATH}" "${INDEX_PATH}" "${PLUGIN_PATH}" "${LOGIN_SELECTOR_PATH}" \
  "${TMP_HTML}" "${TMP_INDEX}" "${TMP_PLUGIN}" "${TMP_LOGIN_SELECTOR}" <<'PY'
import re
import sys
from pathlib import Path

(
    html_path,
    index_path,
    plugin_path,
    login_selector_path,
    tmp_html,
    tmp_index,
    tmp_plugin,
    tmp_login_selector,
) = map(Path, sys.argv[1:])

module_tag = '<script type="module" crossorigin src="./assets/index-e21aa407.js"></script>'
catalog_tag = '<script src="./assets/veeam-zh-CN-catalog.js"></script>'
native_tag = '<script src="./assets/veeam-zh-CN-native.js"></script>'

html = html_path.read_text(encoding='utf-8')
if html.count(module_tag) != 1:
    raise SystemExit('Expected Web UI module script tag was not found exactly once.')
if catalog_tag in html or native_tag in html:
    raise SystemExit('Chinese script tags already exist. Restore or uninstall before retrying.')
html = html.replace(module_tag, catalog_tag + '\n  ' + native_tag + '\n  ' + module_tag, 1)

index = index_path.read_text(encoding='utf-8')
old_registry = 'nF=[l$,c$]'
new_registry = 'nF=[l$,c$,{iso:"zh-CN",title:"简体中文",flag:"",resources:globalThis.__VeeamWebUiZhCatalog}]'
if index.count(old_registry) != 1:
    raise SystemExit('Expected main Web UI language registry was not found exactly once.')
if 'iso:"zh-CN",title:"简体中文"' in index:
    raise SystemExit('The main Web UI bundle already contains a Chinese language entry.')
index = index.replace(old_registry, new_registry, 1)

def patch_language_array(text: str) -> str:
    chinese = '{iso:"zh-CN",title:"简体中文",flag:"",resources:globalThis.__VeeamWebUiZhCatalog}'
    if chinese in text:
        raise SystemExit('plugin.js already contains the Chinese language entry.')
    marker = 'lX=[{iso:"en",title:"English",flag:"",resources:{'
    marker_pos = text.find(marker)
    if marker_pos < 0:
        raise SystemExit('Expected plugin language registry was not found.')
    start = text.find('[', marker_pos)
    depth = 0
    quote = ''
    escaped = False
    end = -1
    for position in range(start, len(text)):
        char = text[position]
        if quote:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = ''
            continue
        if char in ('"', "'", '`'):
            quote = char
        elif char == '[':
            depth += 1
        elif char == ']':
            depth -= 1
            if depth == 0:
                end = position
                break
    if end < 0:
        raise SystemExit('Could not find the end of the plugin language registry.')
    return text[:end] + ',' + chinese + text[end:]

plugin = patch_language_array(plugin_path.read_text(encoding='utf-8'))

selector = login_selector_path.read_text(encoding='utf-8')
if 'data-veeam-zh-native' in selector:
    raise SystemExit('The login language selector already contains the Chinese patch.')

menu_block = """const menu = document.querySelector('.login-page-language-selector__menu');
        if (menu && !menu.querySelector('[data-veeam-zh-native="true"]')) {
            const templateItem = menu.querySelector('.login-page-language-selector__menu-item');
            if (templateItem) {
                const zhItem = templateItem.cloneNode(true);
                zhItem.dataset.veeamZhNative = 'true';
                zhItem.classList.remove('login-page-language-selector__menu-item--selected');
                zhItem.setAttribute('aria-selected', 'false');
                zhItem.querySelector('.login-page-language-selector__menu-item-text').textContent = '\\u7b80\\u4f53\\u4e2d\\u6587';
                const zhInput = zhItem.querySelector('input[name="locale"]');
                if (zhInput) {
                    zhInput.value = 'en';
                    zhInput.dataset.veeamLocale = 'zh-CN';
                }
                menu.appendChild(zhItem);
            }
        }
        const menuItems = document.querySelectorAll('.login-page-language-selector__menu-item');"""
menu_pattern = re.compile(
    r"const menu = document\.querySelector\('\.login-page-language-selector__menu'\);\s*"
    r"const menuItems = document\.querySelectorAll\('\.login-page-language-selector__menu-item'\);",
    re.S,
)
selector, count = menu_pattern.subn(lambda _: menu_block, selector, count=1)
if count != 1:
    raise SystemExit('Expected login language menu block was not found.')

old_locale = 'const localeCode = localeInput.value;'
new_locale = "const localeCode = localeInput.dataset.veeamLocale || localeInput.value;"
if selector.count(old_locale) != 1:
    raise SystemExit('Expected login locale selection statement was not found exactly once.')
selector = selector.replace(old_locale, new_locale, 1)

old_store = "localStorage.setItem('lang', localeCode);"
new_store = """localStorage.setItem('lang', localeCode);
                        localStorage.setItem('localization:language', JSON.stringify(localeCode));"""
if selector.count(old_store) != 1:
    raise SystemExit('Expected login language storage statement was not found exactly once.')
selector = selector.replace(old_store, new_store, 1)

old_restore = 'return localeInput && localeInput.value === storedLang;'
new_restore = "return localeInput && (localeInput.dataset.veeamLocale || localeInput.value) === storedLang;"
if selector.count(old_restore) != 1:
    raise SystemExit('Expected stored login language lookup was not found exactly once.')
selector = selector.replace(old_restore, new_restore, 1)

for path, content in (
    (tmp_html, html),
    (tmp_index, index),
    (tmp_plugin, plugin),
    (tmp_login_selector, selector),
):
    with path.open('w', encoding='utf-8', newline='') as output:
        output.write(content)
PY

chown --reference="${HTML_PATH}" "${TMP_HTML}" 2>/dev/null || true
chmod --reference="${HTML_PATH}" "${TMP_HTML}" 2>/dev/null || true
chown --reference="${INDEX_PATH}" "${TMP_INDEX}" 2>/dev/null || true
chmod --reference="${INDEX_PATH}" "${TMP_INDEX}" 2>/dev/null || true
chown --reference="${PLUGIN_PATH}" "${TMP_PLUGIN}" 2>/dev/null || true
chmod --reference="${PLUGIN_PATH}" "${TMP_PLUGIN}" 2>/dev/null || true
chown --reference="${LOGIN_SELECTOR_PATH}" "${TMP_LOGIN_SELECTOR}" 2>/dev/null || true
chmod --reference="${LOGIN_SELECTOR_PATH}" "${TMP_LOGIN_SELECTOR}" 2>/dev/null || true

install -m 0644 "${SOURCE_NATIVE_ASSET_PATH}" "${NATIVE_ASSET_PATH}"
install -m 0644 "${SOURCE_CATALOG_ASSET_PATH}" "${CATALOG_ASSET_PATH}"
chown --reference="${ASSETS_DIR}" "${NATIVE_ASSET_PATH}" "${CATALOG_ASSET_PATH}" 2>/dev/null || true

mv -f "${TMP_HTML}" "${HTML_PATH}"
mv -f "${TMP_INDEX}" "${INDEX_PATH}"
mv -f "${TMP_PLUGIN}" "${PLUGIN_PATH}"
mv -f "${TMP_LOGIN_SELECTOR}" "${LOGIN_SELECTOR_PATH}"

PATCHED_HTML_SHA256="$(sha256_file "${HTML_PATH}")"
PATCHED_INDEX_SHA256="$(sha256_file "${INDEX_PATH}")"
PATCHED_PLUGIN_SHA256="$(sha256_file "${PLUGIN_PATH}")"
PATCHED_LOGIN_SELECTOR_SHA256="$(sha256_file "${LOGIN_SELECTOR_PATH}")"
NATIVE_ASSET_SHA256="$(sha256_file "${NATIVE_ASSET_PATH}")"
CATALOG_ASSET_SHA256="$(sha256_file "${CATALOG_ASSET_PATH}")"

{
  printf 'BUILD=%q\n' "${BUILD}"
  printf 'WEB_ROOT=%q\n' "${WEB_ROOT}"
  printf 'HTML_PATH=%q\n' "${HTML_PATH}"
  printf 'INDEX_PATH=%q\n' "${INDEX_PATH}"
  printf 'PLUGIN_PATH=%q\n' "${PLUGIN_PATH}"
  printf 'LOGIN_SELECTOR_PATH=%q\n' "${LOGIN_SELECTOR_PATH}"
  printf 'NATIVE_ASSET_PATH=%q\n' "${NATIVE_ASSET_PATH}"
  printf 'CATALOG_ASSET_PATH=%q\n' "${CATALOG_ASSET_PATH}"
  printf 'BACKUP_HTML_PATH=%q\n' "${BACKUP_HTML_PATH}"
  printf 'BACKUP_INDEX_PATH=%q\n' "${BACKUP_INDEX_PATH}"
  printf 'BACKUP_PLUGIN_PATH=%q\n' "${BACKUP_PLUGIN_PATH}"
  printf 'BACKUP_LOGIN_SELECTOR_PATH=%q\n' "${BACKUP_LOGIN_SELECTOR_PATH}"
  printf 'ORIGINAL_HTML_SHA256=%q\n' "${HTML_SHA256}"
  printf 'ORIGINAL_INDEX_SHA256=%q\n' "${INDEX_SHA256}"
  printf 'ORIGINAL_PLUGIN_SHA256=%q\n' "${PLUGIN_SHA256}"
  printf 'ORIGINAL_LOGIN_SELECTOR_SHA256=%q\n' "${LOGIN_SELECTOR_SHA256}"
  printf 'PATCHED_HTML_SHA256=%q\n' "${PATCHED_HTML_SHA256}"
  printf 'PATCHED_INDEX_SHA256=%q\n' "${PATCHED_INDEX_SHA256}"
  printf 'PATCHED_PLUGIN_SHA256=%q\n' "${PATCHED_PLUGIN_SHA256}"
  printf 'PATCHED_LOGIN_SELECTOR_SHA256=%q\n' "${PATCHED_LOGIN_SELECTOR_SHA256}"
  printf 'NATIVE_ASSET_SHA256=%q\n' "${NATIVE_ASSET_SHA256}"
  printf 'CATALOG_ASSET_SHA256=%q\n' "${CATALOG_ASSET_SHA256}"
} > "${MANIFEST_PATH}.new"
mv -f "${MANIFEST_PATH}.new" "${MANIFEST_PATH}"

[[ "$(sha256_file "${HTML_PATH}")" == "${PATCHED_HTML_SHA256}" ]] || die "Patched index.html verification failed."
[[ "$(sha256_file "${INDEX_PATH}")" == "${PATCHED_INDEX_SHA256}" ]] || die "Patched main bundle verification failed."
[[ "$(sha256_file "${PLUGIN_PATH}")" == "${PATCHED_PLUGIN_SHA256}" ]] || die "Patched plugin bundle verification failed."
[[ "$(sha256_file "${LOGIN_SELECTOR_PATH}")" == "${PATCHED_LOGIN_SELECTOR_SHA256}" ]] || die "Patched login selector verification failed."

ROLLBACK_ON_ERROR="no"
trap - EXIT
echo "Veeam Web UI Simplified Chinese package installed for VBR ${BUILD}. Refresh the browser and select Simplified Chinese."
