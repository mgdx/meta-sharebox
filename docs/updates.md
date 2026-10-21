# Storage and updates

This document describes the storage layout of a ShareBox, how A/B updates
work, how a box is updated from a USB stick, and how to build without updates.
The file formats shared with the `/status` CGI are specified in
`docs/ARCHITECTURE.md`, section "Updates".

## Storage layout

Every image is a read-only **erofs** root filesystem (lz4hc compressed) plus a
persistent **/data** partition (ext4). The wic layout depends on
`SHAREBOX_UPDATES`:

| Partition | `SHAREBOX_UPDATES = "1"` (default) | `SHAREBOX_UPDATES = "0"` |
| --- | --- | --- |
| p1 `boot` (vfat, 128M) | firmware, `config.txt`, `cmdline.txt`, DTBs, U-Boot, `boot.scr`, `uboot.env` | same, plus the kernel |
| p2 | rootfs slot A (erofs, 512M), kernel in `/boot` | rootfs (erofs, 512M) |
| p3 | rootfs slot B (512M, empty until the first update) | data (ext4) |
| p4 | data (ext4) | - |

The image is `sharebox-image-<engine>-<machine>.rootfs.wic.gz` (with a
`.wic.bmap`); the erofs file next to it is what goes into the slots and into
the bundles. Flash with `bmaptool copy <image>.wic.gz /dev/sdX`.

The data partition is created at 256M and grown to the end of the card at
first boot by `sharebox-grow-data.service` (sfdisk without re-reading the
table, `partx --update`, then online `resize2fs`). It writes
`/data/.sharebox-grown` when done; delete that file to grow again after
copying the card to a bigger one.

### Early boot, /etc and /var

`sharebox-storage.bbclass` uses the oe-core `overlayfs-etc` class with its
own template (`files/storage/sharebox-preinit.sh.in`): `/sbin/init` is a
small shell script that runs before systemd and

1. runs `e2fsck -p` on the data partition (with `broken_system_clock`, the Pi
   has no RTC) and mounts it on `/data` (`noatime,nodev,nosuid,commit=5`,
   barriers on);
2. mounts `/etc` and `/var` as overlays: lower layer from the image, upper
   layers in `/data/overlay/etc` and `/data/overlay/var` (mode 0700);
3. after an update (the image `/etc/timestamp` changed), deletes the
   persistent copies of `passwd`, `group`, `shadow`, `gshadow`, `subuid`,
   `subgid`, so that system users added by the new image are visible;
4. starts systemd (`/sbin/init.orig`).

If the data partition cannot be checked or mounted, `/data` becomes a 64M
tmpfs (`/data/.sharebox-data-fallback` exists), the box still boots, and
nothing persists. `/var/log` and `/var/tmp` stay volatile (oe-core symlinks
to `/var/volatile`, a tmpfs), journald is volatile; everything else in `/var`
(`/var/lib`, `/var/cache`, `/var/spool`) persists on `/data`.

Configuration files changed at run time persist across updates. A file of
`/etc` that was modified on the box hides the version shipped by a newer
image: ShareBox keeps run-time settings in `/data/config`, not in `/etc`.

## A/B updates

RAUC 1.15 with the U-Boot backend, two root filesystem slots:

| RAUC slot | Device | `bootname` |
| --- | --- | --- |
| `rootfs.0` | p2 | A |
| `rootfs.1` | p3 | B |

`/usr/lib/rauc/system.conf`: `compatible=sharebox-<MACHINE>`,
`bundle-formats=verity`, `bootloader=uboot`, slots of type `raw` (RAUC has no
erofs type, the erofs image is written as is), `mountprefix=/run/rauc`,
`data-directory=/data/rauc`, keyring `/usr/lib/rauc/ca.cert.pem`. The data
partition is never a slot.

### Boot selection

U-Boot (`RPI_USE_U_BOOT = "1"`) runs `boot.scr`
(`recipes-bsp/rpi-u-boot-scr/files/boot.cmd.in`, derived from
meta-rauc-raspberrypi). Its environment (`uboot.env` on the boot partition,
also read and written by `fw_setenv` through `/etc/fw_env.config`, which is
why the boot partition is mounted on `/boot`) holds:

- `BOOT_ORDER`: `A B` or `B A`, set by RAUC when a slot is installed;
- `BOOT_A_LEFT`, `BOOT_B_LEFT`: boot attempts left (3, reset by
  `rauc status mark-good`). Slot B starts at 0 because it is empty.

At each boot the script picks the first slot of `BOOT_ORDER` with attempts
left, decrements its counter, saves the environment, loads
`/boot/Image` from that erofs slot (U-Boot `CONFIG_FS_EROFS`) and boots it
with `root=/dev/mmcblk0pN rauc.slot=A|B rootfstype=erofs ro` (the rest of the
command line comes from `cmdline.txt`, which includes `panic=10` so that a
kernel panic reboots). A slot without a loadable kernel is disabled at once.
When no slot has attempts left, both counters are reset to 3.

The kernel, its modules and the userspace are in the slot, so a bundle
updates all of them at once. The boot partition (firmware, device trees,
overlays, `config.txt`, U-Boot, `boot.scr`) is static: changing it requires
a reflash. See `docs/deviations.md` for the reasons and the fallback.

### Committing a slot: sharebox-healthcheck

`sharebox-healthcheck.service` (instead of meta-rauc's `rauc-mark-good`,
excluded with `BAD_RECOMMENDATIONS`) waits up to 180 s for `hostapd.service`
and `dnsmasq.service` to be active and for a listener on TCP port 80, then
runs `rauc status mark-good`.

- Trial boot (the slot was just installed by `sharebox-install-update`, see
  `/data/rauc/sharebox-pending-update`): if the box is not healthy in time,
  `rauc status mark-bad` and reboot into the previous slot.
- Any other boot: the slot is marked good even if the box is unhealthy (that
  is a configuration or hardware problem, not a bad update) and a line is
  added to `/run/sharebox/warnings`.
- A slot that never reaches user space (kernel panic, hang with the
  watchdog) uses up its 3 attempts and U-Boot falls back to the other slot.

After an update, the result (`installed`, `rolled-back`) is written to
`/run/sharebox/update-status` for the `/status` page.

## Updating from a USB stick

1. Copy the bundle to the stick as `sharebox/<anything>.raucb` (for example
   `sharebox/sharebox-bundle-modular-raspberrypi4-64.raucb`). If several are
   present, the last one in name order is used.
2. Plug the stick in. `sharebox-usb-scan.service` runs the hooks of
   `/usr/lib/sharebox/usb-hooks.d/`; `50-rauc` runs `rauc info`, which checks
   the signature against the keyring, compares the bundle compatible with the
   box, and writes `/run/sharebox/update-candidate`.
3. The `/status` page shows the update and an "Install" button. Nothing is
   installed without that confirmation.
4. The button posts the form; the CGI (unprivileged) runs
   `/usr/lib/sharebox/sharebox-install-update <bundle name>`, which only
   queues the request. `sharebox-update-install.path` starts
   `sharebox-update-install.service` (root), which runs `rauc install`
   (signature, compatible and dm-verity checked again), records the trial in
   `/data/rauc/sharebox-pending-update` and reboots.
5. The new slot boots; `sharebox-healthcheck` commits it, or rolls back.

Progress and errors are in `/run/sharebox/update-status` and in the journal
(`journalctl -u sharebox-usb-scan -u sharebox-update-install -u
sharebox-healthcheck -u rauc`).

The real protection is the signature: the network is open and anybody
associated with the box can press "Install", but only bundles signed with
the build's key are accepted.

From a shell (development distro): `rauc info /media/usb-*/sharebox/x.raucb`,
`rauc install ...`, `rauc status --detailed`.

## Building bundles

One bundle recipe per image, `sharebox-bundle-<engine>`:

```
bitbake sharebox-bundle-modular
# tmp/deploy/images/<machine>/sharebox-bundle-modular-<machine>.raucb
```

The bundle builds the image it contains. Signing keys:
`files/rauc-keys/README.md`. With the default development keys, the build
warns for the `sharebox` distro (not for `sharebox-dev`).

## Building without updates

```
SHAREBOX_UPDATES = "0"
```

in `local.conf` or a kas file (it is a build-time choice only, there is no
run-time equivalent). Then:

- `rauc`, `sharebox-update` and `sharebox-healthcheck` are not installed
  (`packagegroup-sharebox-base`), `rauc` is removed from `DISTRO_FEATURES`
  and the `sharebox-bundle-*` recipes are skipped;
- the wic image has a single rootfs partition (`wic/sharebox-single.wks.in`),
  the data partition is p3;
- the kernel stays on the boot partition and the stock meta-raspberrypi
  `boot.scr` is used (no A/B logic, no U-Boot erofs);
- the USB hook is absent, so `.raucb` files on sticks are ignored and the
  `/status` page shows no install button.

The only way to update such a box is to reflash the card.

## Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `SHAREBOX_UPDATES` | `1` | A/B updates with RAUC |
| `SHAREBOX_DATA_FS` | `ext4` | data filesystem (`ext4`, `ext3`, `ext2`) |
| `SHAREBOX_DISK` | `mmcblk0` | boot disk as seen by Linux |
| `SHAREBOX_UBOOT_DISK` | `mmc 0` | boot disk as seen by U-Boot |
| `SHAREBOX_BOOT_SIZE` | `128M` | boot partition |
| `SHAREBOX_ROOTFS_SIZE` | `512M` | each rootfs slot (the build fails if the erofs image is bigger) |
| `SHAREBOX_DATA_SIZE` | `256M` | initial data partition, grown at first boot |
| `SHAREBOX_EROFS_OPTS` | `-zlz4hc` | `mkfs.erofs` options |
| `SHAREBOX_IMAGE_FSTYPES` | `erofs wic.gz wic.bmap` | image types |
| `SHAREBOX_RAUC_COMPATIBLE` | `sharebox-${MACHINE}` | RAUC compatible |
| `RAUC_KEY_FILE`, `RAUC_CERT_FILE`, `RAUC_KEYRING_FILE` | development keys | signing, see `files/rauc-keys/README.md` |

Partition devices and numbers are defined once in
`conf/distro/include/sharebox-storage.inc`.
