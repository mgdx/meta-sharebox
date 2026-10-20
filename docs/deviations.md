# Deviations from the specification

## Storage and updates

### No dependency on meta-rauc-raspberrypi

The specification lists meta-rauc-raspberrypi (meta-rauc-community) as a
layer dependency and reuses its wks, boot script and
`grow-data-partition` service. That layer is a demonstration layer: it
bbappends `core-image-minimal`, `base-files` (fstab), `udev-extraconf` and
`linux-raspberrypi` unconditionally for its own partition layout, which
conflicts with ShareBox (erofs instead of ext4, `/data` instead of `/home`).

meta-sharebox does not depend on it. The parts that are needed are
reimplemented in the layer, with attribution in the files (MIT):

| meta-rauc-raspberrypi | meta-sharebox |
| --- | --- |
| `files/wic/sdimage-dual-raspberrypi.wks.in` | `wic/sharebox-dual.wks.in` |
| `recipes-bsp/rpi-u-boot-scr/files/boot.cmd.in` | `recipes-bsp/rpi-u-boot-scr/files/boot.cmd.in` |
| `recipes-core/rauc/files/system.conf` | `recipes-support/rauc/files/system.conf` |
| `recipes-core/bundles/update-bundle.bb` | `recipes-core/bundles/sharebox-bundle.inc` |
| `rauc-grow-data-partition.service` (parted) | `sharebox-grow-data.service` (sfdisk, partx, resize2fs) |
| `recipes-kernel/linux/files/rauc.cfg` | `recipes-kernel/linux/sharebox-storage/sharebox-storage.cfg` |

### Kernel in the rootfs slot, static boot partition

Open point of the specification ("noyau et DTB dans le rootfs ou dans le
bundle"). Decision: the kernel is `/boot/Image` inside each erofs slot and
U-Boot reads it from there (U-Boot 2026.01 `CONFIG_FS_EROFS`, with lz4
decompression, enabled by `recipes-bsp/u-boot/files/sharebox-erofs.cfg`).
A bundle therefore updates kernel, modules and userspace atomically, and the
boot partition is never written by RAUC (only `uboot.env` changes).

The device trees and overlays stay on the static boot partition: the Pi
firmware loads and patches them before U-Boot runs. A kernel update that
needs new device trees, or a firmware/U-Boot update, requires a reflash.
This is the same trade-off as meta-rauc-raspberrypi.

Fallback if U-Boot cannot read the erofs slot on some machine: add a pair
of small vfat partitions (`boot_a`, `boot_b`) holding the kernel, declared
as RAUC slots of class `kernel` with `parent=rootfs.N`, and let the boot
script `fatload` from the selected one; the bundle then carries the kernel
as a second image. This costs two partitions (an extended partition with
msdos) and is not implemented, since U-Boot 2026.01 reads erofs.

### Pi 5

Same U-Boot path as the other machines (specification default). The RAUC
`tryboot` alternative is not implemented. Not validated on hardware.

### Partition table and partition names

msdos label, four primary partitions (boot, A, B, data). erofs partitions
have no filesystem label (erofs has none and wic refuses one): devices are
referenced by number (`/dev/mmcblk0pN`, `mmc 0:N`) from a single definition,
`conf/distro/include/sharebox-storage.inc`. Booting from USB mass storage is
possible by setting `SHAREBOX_DISK` and `SHAREBOX_UBOOT_DISK`.

### /var

The specification says "un montage `/var` sur `/data/var`". `/var` is an
overlay (lower: the image, upper: `/data/overlay/var/upper`) mounted by the
preinit together with `/etc`, rather than a bind mount of `/data/var`: the
content that packages put in `/var` at build time stays visible and new
images can add to it. `/var/log` and `/var/tmp` remain volatile
(`/var/volatile`, tmpfs), as journald. `/data/var` is not used.

### /etc overlay upper directory

`/data/overlay/etc` instead of oe-core's default `/data/overlay-etc`, next to
`/data/overlay/var`. The preinit is a ShareBox template for
`overlayfs-etc.bbclass` (fsck, `/var` overlay, RAM fallback, account
databases reset after an update) instead of the oe-core default, which
remounts `/` read-write (impossible on erofs).

### Data partition growth

Online, after `/data` is mounted (the overlays live on it), with sfdisk
`--no-reread` + `partx --update` + `resize2fs`, like cloud-utils `growpart`.
`parted resizepart` (meta-rauc-raspberrypi) refuses or asks for confirmation
on a partition in use, and systemd-repart only handles GPT.

### Image types

`IMAGE_FSTYPES = "erofs wic.gz wic.bmap"` (`SHAREBOX_IMAGE_FSTYPES`). The
erofs image is built with `-zlz4hc` (lz4 format, better ratio than `-zlz4`,
same decompressor). The wic image copies it with the `rawcopy` source so that
the flashed slot and the bundle payload are the same file.

### Keyring location

`/usr/lib/rauc/ca.cert.pem` (where meta-rauc's `rauc-conf` installs it, next
to `system.conf`), not `/etc/rauc/ca.cert.pem`: `/etc` is a writable overlay
whose content can survive updates, the keyring must come from the image.

### RAUC features

`rauc` is built without `network`, `streaming`, `gpt` and `json`
(`PACKAGECONFIG`): the box is offline, bundles only come from USB sticks.
Slot type `raw`: RAUC 1.15 has no erofs handler.

### Mark-good

`sharebox-healthcheck.service` replaces meta-rauc's `rauc-mark-good.service`
(dropped with `BAD_RECOMMENDATIONS`), so that a slot is only committed once
the access point, DHCP/DNS and the web front end are up. Outside a trial boot
an unhealthy box is still committed (see `docs/updates.md`).
