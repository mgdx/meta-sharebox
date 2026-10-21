#!/bin/sh
# SPDX-License-Identifier: MIT
# Write a ShareBox image to an SD card (or USB disk) with bmaptool, after
# safety checks: the target must be a whole removable disk (SD card, USB),
# with no mounted partition, not the disk of the running system, and the
# user must confirm.
set -eu

usage() {
    cat <<EOF
Usage: $0 [-y] [-b BMAP] IMAGE DEVICE

  IMAGE   sharebox-image-<engine>-<machine>.rootfs.wic.gz (or .wic, .wic.xz...)
  DEVICE  whole disk, e.g. /dev/sdX or /dev/mmcblk0 (not a partition)

Options:
  -b BMAP  block map file (default: IMAGE without the compression suffix
           and .wic replaced by .wic.bmap, when it exists)
  -y       do not ask for confirmation (the safety checks still apply)
  -h       this help

Runs bmaptool through sudo when not root. Example:
  $0 build/tmp/deploy/images/raspberrypi4-64/sharebox-image-modular-raspberrypi4-64.rootfs.wic.gz /dev/sdX
EOF
}

die() { echo "error: $*" >&2; exit 1; }

YES=0
BMAP=""
while getopts "b:yh" opt; do
    case $opt in
        b) BMAP=$OPTARG ;;
        y) YES=1 ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 2 ] || { usage >&2; exit 2; }
IMAGE=$1
DEV=$2

command -v bmaptool >/dev/null 2>&1 || die "bmaptool not found (apt install bmap-tools, or pipx install bmaptool)"
command -v lsblk >/dev/null 2>&1 || die "lsblk not found (util-linux)"

[ -f "$IMAGE" ] || die "image '$IMAGE' not found"
case $IMAGE in
    *.wic|*.wic.gz|*.wic.bz2|*.wic.xz|*.wic.zst|*.wic.lz4) ;;
    *) die "'$IMAGE' is not a .wic image" ;;
esac

if [ -z "$BMAP" ]; then
    base=${IMAGE%.gz}; base=${base%.bz2}; base=${base%.xz}; base=${base%.zst}; base=${base%.lz4}
    [ -f "$base.bmap" ] && BMAP=$base.bmap
fi
[ -z "$BMAP" ] || [ -f "$BMAP" ] || die "block map '$BMAP' not found"

# --- target device checks ----------------------------------------------------

[ -b "$DEV" ] || die "'$DEV' is not a block device"
DEV=$(readlink -f "$DEV")
name=$(basename "$DEV")
sys=/sys/class/block/$name
[ -e "$sys" ] || die "no $sys"
[ ! -e "$sys/partition" ] || die "'$DEV' is a partition; give the whole disk"

type=$(lsblk -dno TYPE "$DEV" 2>/dev/null || true)
[ "$type" = disk ] || die "'$DEV' is not a disk (type '$type')"

removable=$(cat "/sys/block/$name/removable" 2>/dev/null || echo 0)
tran=$(lsblk -dno TRAN "$DEV" 2>/dev/null | tr -d ' ' || true)
case $name in
    mmcblk*) media=sd ;;
    *)
        if [ "$removable" = 1 ] || [ "$tran" = usb ]; then
            media=removable
        else
            media=""
        fi
        ;;
esac
[ -n "$media" ] || die "'$DEV' is not a removable disk (removable=$removable, transport='${tran:-?}'); refusing"

# Nothing of the target may be mounted or used as swap
mounted=$(lsblk -nro MOUNTPOINTS "$DEV" 2>/dev/null || lsblk -nro MOUNTPOINT "$DEV")
mounted=$(printf '%s\n' "$mounted" | grep -v '^$' || true)
[ -z "$mounted" ] || die "'$DEV' has mounted file systems, unmount them first:
$mounted"
for part in $(lsblk -nro NAME "$DEV"); do
    if grep -q "^/dev/$part " /proc/swaps 2>/dev/null; then
        die "/dev/$part is used as swap"
    fi
done

# Not the disk of the running system
rootsrc=$(findmnt -nro SOURCE / 2>/dev/null || true)
if [ -n "$rootsrc" ] && [ -b "$rootsrc" ]; then
    rootdisk=$(lsblk -nrso NAME "$rootsrc" 2>/dev/null | tail -n 1)
    [ "$rootdisk" != "$name" ] || die "'$DEV' holds the running system"
fi

size=$(lsblk -dnbo SIZE "$DEV" | tr -d ' ')
model=$(lsblk -dno MODEL "$DEV" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
gib=$((size / 1073741824))

echo "Image:  $IMAGE"
echo "Bmap:   ${BMAP:-none (whole image is written)}"
echo "Target: $DEV  ${model:-unknown model}, $gib GiB, $media${tran:+ ($tran)}"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEV" || true
if [ "$gib" -gt 256 ]; then
    echo "warning: the target is larger than 256 GiB, are you sure it is an SD card?"
fi

if [ "$YES" -eq 0 ]; then
    printf 'ALL DATA ON %s WILL BE LOST. Type "yes" to continue: ' "$DEV"
    read -r answer
    [ "$answer" = yes ] || die "aborted"
fi

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO=sudo
if [ -n "$BMAP" ]; then
    $SUDO bmaptool copy --bmap "$BMAP" "$IMAGE" "$DEV"
else
    $SUDO bmaptool copy --nobmap "$IMAGE" "$DEV"
fi
sync
echo "done: $DEV can be removed"
