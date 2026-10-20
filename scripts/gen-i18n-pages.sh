#!/bin/sh
# SPDX-License-Identifier: MIT
# Regenerate the ShareBox home pages and SSID files from the i18n sources.
# Developer-host tool only (needs python3), never part of an image.
# Commit the generated files under recipes-core/sharebox-config/files/.
set -eu
here=$(dirname "$0")
python3 "$here/gen-i18n-pages.py" "$@"
"$here/check-i18n.sh"
