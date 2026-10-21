#!/bin/sh
# SPDX-License-Identifier: MIT
# Look for interpreters in the package manifests of ShareBox images. No
# python3*, perl*, php* or nodejs* package may be installed (specification,
# "Tests de build"). The image build already enforces it
# (SHAREBOX_FORBIDDEN_PACKAGES in sharebox-image.bbclass); this script
# checks the published manifests, e.g. in CI or before a release.
set -eu

usage() {
    cat <<EOF
Usage: $0 [-p "PREFIXES"] [DEPLOY_DIR | MANIFEST...]

  DEPLOY_DIR  tmp/deploy/images/<machine> of a build, every
              sharebox-image-*.rootfs.manifest in it is checked
              (default: build/tmp/deploy/images/raspberrypi4-64)
  MANIFEST    or explicit manifest files ("<package> <arch> <version>" lines)
  -p PREFIXES forbidden package name prefixes (default: "python3 perl php nodejs")
  -h          this help

Exit status: 0 clean, 1 forbidden package found, 2 usage error, 3 no
manifest found.
EOF
}

PREFIXES="python3 perl php nodejs"
while getopts "p:h" opt; do
    case $opt in
        p) PREFIXES=$OPTARG ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || set -- build/tmp/deploy/images/raspberrypi4-64

# Build the manifest list (one per line). Link names
# (<image>-<machine>.rootfs.manifest) are preferred over time-stamped ones.
manifests=""
for arg in "$@"; do
    if [ -d "$arg" ]; then
        for m in "$arg"/sharebox-image-*.rootfs.manifest; do
            [ -e "$m" ] && manifests="$manifests$m
"
        done
        for m in "$arg"/sharebox-image-*.rootfs-*.manifest; do
            [ -e "$m" ] || continue
            link=$(printf '%s\n' "$m" | sed 's/\.rootfs-[^/]*\.manifest$/.rootfs.manifest/')
            [ -e "$link" ] || manifests="$manifests$m
"
        done
    elif [ -f "$arg" ]; then
        manifests="$manifests$arg
"
    else
        echo "error: '$arg' is neither a directory nor a file" >&2
        exit 2
    fi
done

if [ -z "$manifests" ]; then
    echo "error: no sharebox-image-*.rootfs.manifest found in: $*" >&2
    exit 3
fi

# awk regex: ^(python3|perl|php|nodejs)
re=$(printf '%s\n' $PREFIXES | sed 's/[][\.*^$+?(){}|/]/\\&/g' | paste -sd '|' -)
[ -n "$re" ] || { echo "error: empty prefix list" >&2; exit 2; }

bad=0
count=0
old_ifs=$IFS
IFS='
'
for m in $manifests; do
    IFS=$old_ifs
    count=$((count + 1))
    found=$(awk -v re="^($re)" '$1 ~ re { print $1 }' "$m" | sort -u)
    if [ -n "$found" ]; then
        bad=$((bad + 1))
        echo "FAIL $(basename "$m"):"
        printf '%s\n' "$found" | sed 's/^/    /'
    else
        echo "OK   $(basename "$m") ($(wc -l < "$m" | tr -d ' ') packages)"
    fi
done
IFS=$old_ifs

echo
echo "$count manifest(s) checked, $bad with forbidden packages (prefixes: $PREFIXES)"
[ "$bad" -eq 0 ]
