#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="VeeamWebUiZhCN-13.0.2.29"
SOURCE_PARENT="${REPO_ROOT}/package-src/VBR-13.0.2.29"
OUTPUT_PATH="${REPO_ROOT}/VBR WebUI Chinese Package/VBR-13.0.2.29/${PACKAGE_NAME}-linux.tar.gz"
TEMP_OUTPUT="${OUTPUT_PATH}.new.$$"

node "${REPO_ROOT}/tools/test-vbr-13.0.2.29-native-guard.js"
node "${REPO_ROOT}/tools/test-vbr-13.0.2.29-catalog-placeholders.js"

COPYFILE_DISABLE=1 tar \
  --no-xattrs \
  --exclude='._*' \
  -cf - \
  -C "${SOURCE_PARENT}" \
  "${PACKAGE_NAME}" | gzip -n > "${TEMP_OUTPUT}"

if gzip -dc "${TEMP_OUTPUT}" | strings | grep -Eq 'LIBARCHIVE\.xattr|(^|/)\._'; then
  echo "ERROR: macOS extended attributes or AppleDouble entries remain in the archive." >&2
  exit 1
fi

mv "${TEMP_OUTPUT}" "${OUTPUT_PATH}"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${OUTPUT_PATH}"
else
  shasum -a 256 "${OUTPUT_PATH}"
fi
