#!/bin/sh
# SPDX-License-Identifier: MIT
# Build every ShareBox image for every machine it is compatible with, using
# the kas files of the layer. Compatibility is read from COMPATIBLE_MACHINE
# in recipes-core/images/sharebox-image-<engine>.bb (no COMPATIBLE_MACHINE:
# every machine).
set -eu

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -m MACHINES  kas files to use, space separated basenames of kas/*.yml
               (default: "rpi0-w rpi0-2w-64 rpi3-64 rpi4-64 rpi5")
  -i IMAGES    engines to build (default: "base classic modular shareboxx library full")
  -o OVERLAY   extra kas overlay appended to every build, e.g. kas/dev.yml
               or kas/local.yml (must be inside this repository)
  -b           also build the RAUC bundle of each image (sharebox-bundle-<engine>)
  -k           keep going after a failed build (default: stop)
  -n           dry run: print the kas commands only
  -h           this help

Environment: KAS (default: kas), KAS_WORK_DIR and the other kas variables.

Examples:
  $0 -m rpi4-64
  $0 -m "rpi4-64 rpi5" -i "modular full" -o kas/local.yml -k
EOF
}

TOP=$(cd "$(dirname "$0")/.." && pwd)
KAS=${KAS:-kas}
MACHINES="rpi0-w rpi0-2w-64 rpi3-64 rpi4-64 rpi5"
IMAGES="base classic modular shareboxx library full"
OVERLAY=""
BUNDLE=0
KEEP_GOING=0
DRY_RUN=0

while getopts "m:i:o:bknh" opt; do
    case $opt in
        m) MACHINES=$OPTARG ;;
        i) IMAGES=$OPTARG ;;
        o) OVERLAY=$OPTARG ;;
        b) BUNDLE=1 ;;
        k) KEEP_GOING=1 ;;
        n) DRY_RUN=1 ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 0 ] || { usage >&2; exit 2; }

cd "$TOP"

if [ "$DRY_RUN" -eq 0 ] && ! command -v "$KAS" >/dev/null 2>&1; then
    echo "error: '$KAS' not found (pipx install kas)" >&2
    exit 1
fi
if [ -n "$OVERLAY" ] && [ ! -f "$OVERLAY" ]; then
    echo "error: overlay '$OVERLAY' not found" >&2
    exit 1
fi

# MACHINE value of a kas file
kas_machine() {
    sed -n 's/^machine:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$1" | head -n 1
}

# COMPATIBLE_MACHINE regular expression of an image recipe, empty if none
image_compat() {
    sed -n 's/^COMPATIBLE_MACHINE[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$1" | tail -n 1
}

ok=""
failed=""
skipped=""
for m in $MACHINES; do
    kasfile=kas/$m.yml
    if [ ! -f "$kasfile" ]; then
        echo "error: $kasfile not found" >&2
        exit 1
    fi
    machine=$(kas_machine "$kasfile")
    if [ -z "$machine" ]; then
        echo "error: no 'machine:' in $kasfile" >&2
        exit 1
    fi
    config=$kasfile
    [ -z "$OVERLAY" ] || config=$config:$OVERLAY

    for e in $IMAGES; do
        recipe=recipes-core/images/sharebox-image-$e.bb
        if [ ! -f "$recipe" ]; then
            echo "error: $recipe not found" >&2
            exit 1
        fi
        compat=$(image_compat "$recipe")
        if [ -n "$compat" ] && ! printf '%s\n' "$machine" | grep -Eq -- "$compat"; then
            echo "skip: sharebox-image-$e is not compatible with $machine"
            skipped="$skipped $e/$machine"
            continue
        fi
        set -- --target "sharebox-image-$e"
        [ "$BUNDLE" -eq 0 ] || set -- "$@" --target "sharebox-bundle-$e"
        echo "=== $machine: sharebox-image-$e"
        echo "+ $KAS build $config $*"
        [ "$DRY_RUN" -eq 0 ] || continue
        if "$KAS" build "$config" "$@"; then
            ok="$ok $e/$machine"
        else
            failed="$failed $e/$machine"
            if [ "$KEEP_GOING" -eq 0 ]; then
                echo "error: build of sharebox-image-$e for $machine failed" >&2
                exit 1
            fi
        fi
    done
done

echo
echo "built:  ${ok:- none}"
echo "skipped:${skipped:- none}"
echo "failed: ${failed:- none}"
[ -z "$failed" ]
