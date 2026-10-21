#!/bin/sh
# SPDX-License-Identifier: MIT
# Compare the size of the ShareBox root filesystem images (erofs) in a deploy
# directory with the footprint targets of the specification ("Seuils
# d'empreinte", measured for a Pi 4):
#
#   image      rootfs erofs target
#   base       90 MiB
#   classic   100 MiB
#   modular   130 MiB
#   shareboxx 120 MiB
#   library   150 MiB
#   full      180 MiB
#
# Above the target: REVIEW (the specification asks for a review, not a
# rejection). More than 20 % above the target: FAIL, exit status 1.
# RAUC bundle sizes, when present, are listed for information.
set -eu

usage() {
    cat <<EOF
Usage: $0 [-q] [DEPLOY_DIR]

  DEPLOY_DIR  tmp/deploy/images/<machine> of a build
              (default: build/tmp/deploy/images/raspberrypi4-64)
  -q          print only REVIEW and FAIL lines
  -h          this help

Exit status: 0 all within +20 % of the targets, 1 at least one image more
than 20 % above its target, 2 usage error, 3 no image found.
Sizes are in MiB (1048576 bytes). When GITHUB_STEP_SUMMARY is set, a
Markdown table is appended to it.
EOF
}

QUIET=0
while getopts "qh" opt; do
    case $opt in
        q) QUIET=1 ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -le 1 ] || { usage >&2; exit 2; }
DEPLOY=${1:-build/tmp/deploy/images/raspberrypi4-64}
[ -d "$DEPLOY" ] || { echo "error: '$DEPLOY' is not a directory" >&2; exit 2; }

threshold() { # threshold ENGINE -> MiB, or nothing
    case $1 in
        base) echo 90 ;;
        classic) echo 100 ;;
        modular) echo 130 ;;
        shareboxx) echo 120 ;;
        library) echo 150 ;;
        full) echo 180 ;;
    esac
}

# Size in bytes of a file (following symlinks)
fsize() { wc -c < "$1" | tr -d ' '; }

# One decimal MiB value
mib() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }

# Rootfs images: prefer the stable link names
# (sharebox-image-<engine>-<machine>.rootfs.erofs); fall back to the newest
# time-stamped file when the link is missing.
list_images() {
    for f in "$DEPLOY"/sharebox-image-*.rootfs.erofs; do
        [ -e "$f" ] && printf '%s\n' "$f"
    done
    for f in "$DEPLOY"/sharebox-image-*.rootfs-*.erofs; do
        [ -e "$f" ] || continue
        link=$(printf '%s\n' "$f" | sed 's/\.rootfs-[^/]*\.erofs$/.rootfs.erofs/')
        [ -e "$link" ] || printf '%s\n' "$f"
    done | sort -r | awk -F'.rootfs-' '!seen[$1]++'
}

summary=""
add_summary() { summary="$summary$1
"; }

found=0
fail=0
review=0
fmt='%-10s %-20s %9s %8s %7s  %s\n'
[ "$QUIET" -eq 1 ] || printf "$fmt" IMAGE MACHINE "SIZE MiB" "TARGET" "RATIO" STATUS
add_summary "| Image | Machine | Size (MiB) | Target (MiB) | Ratio | Status |"
add_summary "| --- | --- | --- | --- | --- | --- |"

for f in $(list_images); do
    found=$((found + 1))
    base=$(basename "$f")
    rest=${base#sharebox-image-}
    engine=${rest%%-*}
    machine=${rest#"$engine"-}
    machine=${machine%%.rootfs*}
    bytes=$(fsize "$f")
    size=$(mib "$bytes")
    target=$(threshold "$engine")
    if [ -z "$target" ]; then
        status="UNKNOWN (no target for '$engine')"
        ratio="-"
        target="-"
    else
        ratio=$(awk -v b="$bytes" -v t="$target" 'BEGIN { printf "%.0f%%", 100 * b / (t * 1048576) }')
        limit=$((target * 1048576))
        fail_limit=$((target * 1048576 * 12 / 10))
        if [ "$bytes" -gt "$fail_limit" ]; then
            status="FAIL (more than 20 % above target)"
            fail=$((fail + 1))
        elif [ "$bytes" -gt "$limit" ]; then
            status="REVIEW (above target)"
            review=$((review + 1))
        else
            status="OK"
        fi
    fi
    case $status in
        OK|UNKNOWN*) [ "$QUIET" -eq 1 ] || printf "$fmt" "$engine" "$machine" "$size" "$target" "$ratio" "$status" ;;
        *) printf "$fmt" "$engine" "$machine" "$size" "$target" "$ratio" "$status" ;;
    esac
    add_summary "| $engine | $machine | $size | $target | $ratio | $status |"
done

if [ "$found" -eq 0 ]; then
    echo "error: no sharebox-image-*.rootfs.erofs in $DEPLOY" >&2
    exit 3
fi

# RAUC bundles (information only)
bundles=0
for b in "$DEPLOY"/sharebox-bundle-*.raucb; do
    [ -e "$b" ] || continue
    # skip the time-stamped files (<name>-<machine>-YYYYMMDDhhmmss.raucb),
    # the link names point to the newest ones
    case $b in *-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].raucb) continue ;; esac
    if [ "$bundles" -eq 0 ]; then
        [ "$QUIET" -eq 1 ] || { echo; echo "RAUC bundles:"; }
        add_summary ""
        add_summary "| Bundle | Size (MiB) |"
        add_summary "| --- | --- |"
    fi
    bundles=$((bundles + 1))
    bsize=$(mib "$(fsize "$b")")
    [ "$QUIET" -eq 1 ] || printf '  %-50s %9s MiB\n' "$(basename "$b")" "$bsize"
    add_summary "| $(basename "$b") | $bsize |"
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo "### Root filesystem sizes"; echo; printf '%s' "$summary"; } >> "$GITHUB_STEP_SUMMARY"
fi

echo
echo "$found image(s): $fail FAIL, $review REVIEW"
[ "$fail" -eq 0 ]
