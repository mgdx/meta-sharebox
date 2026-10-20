# meta-sharebox architecture and internal conventions

This document is the contract between the parts of the layer. Every recipe
must follow it so that the base system and the sharing engines fit together.

## Target

- Yocto 6.0 Wrynose (`LAYERSERIES_COMPAT = "wrynose blacksail"`), bitbake 2.18.
- BSP: meta-raspberrypi only. Reference build machine: `raspberrypi4-64`.
- Distro: `sharebox` (production) and `sharebox-dev` (adds dropbear, UART).
- systemd + glibc, no Python/Perl/PHP/Node.js on target.

Versions available in Wrynose differ slightly from the original specification:
hostapd 2.11 (meta-oe), lighttpd 1.4.82 (oe-core), systemd 259, rauc 1.15.2.
xapian-core and ntfs-3g are not packaged in Wrynose and are provided (or
dropped) by this layer. See `docs/deviations.md`.

## Layer layout

| Path | Owner / content |
| --- | --- |
| `conf/distro/` | distro and includes (`sharebox-features.inc`, `sharebox-security.inc`, `sharebox-rpi.inc`) |
| `classes/sharebox-image.bbclass` | common image logic, inherited by every image |
| `classes/sharebox-storage.bbclass` | read-only rootfs, erofs, overlayfs-etc, wks selection, RAUC bundle hooks |
| `recipes-core/images/sharebox-image-<engine>.bb` | one image per engine |
| `recipes-core/packagegroups/packagegroup-sharebox-*.bb` | `base`, `frontend`, `engine-<engine>` |
| `recipes-core/sharebox-config/` | runtime configuration generator, home pages, i18n data |
| `recipes-connectivity/{hostapd,dnsmasq,nftables,captive-portal}` | access point, DHCP/DNS, firewall, captive probes |
| `recipes-webserver/{lighttpd,gamja}` | HTTP front end and static IRC client |
| `recipes-sharing/{dufs,ergo,luffy,shareboxx,sriracha}` | sharing engines |
| `recipes-kiwix/{xapian-core,libzim,libkiwix,kainjow-mustache,kiwix-tools}` | offline library |
| `recipes-support/{usb-automount,rauc,sharebox-healthcheck,sharebox-update,sharebox-storage}` | USB sticks, updates, data partition growth |
| `recipes-core/bundles/` | `sharebox-bundle-<engine>.bb`, one RAUC bundle per image |
| `recipes-bsp/{u-boot,rpi-u-boot-scr,rpi-cmdline}` | U-Boot erofs fragment, A/B boot script, `cmdline.txt` (erofs root) |
| `recipes-kernel/linux/` | `linux-raspberrypi` bbappend and config fragments |
| `conf/distro/include/sharebox-storage.inc` | partition numbers and devices, data mount options (required by the storage recipes) |
| `files/storage/`, `files/rauc-keys/` | preinit template, RAUC keys (development keys and README) |
| `wic/` | partition layouts |
| `kas/` | reproducible build configurations |

## Engines and images

`SHAREBOX_ENGINE` is set by each image recipe: `base`, `classic`, `modular`,
`shareboxx`, `library`, `full`.

| Image | Packagegroups | HTTP on port 80 |
| --- | --- | --- |
| `sharebox-image-base` | base + frontend | lighttpd |
| `sharebox-image-classic` | base + engine-classic | luffy |
| `sharebox-image-modular` | base + frontend + engine-modular | lighttpd |
| `sharebox-image-shareboxx` | base + engine-shareboxx | shareboxx |
| `sharebox-image-library` | base + frontend + engine-library | lighttpd |
| `sharebox-image-full` | base + frontend + engine-modular + engine-library | lighttpd |

An image recipe is short:

```
SUMMARY = "ShareBox image with the modular engine"
LICENSE = "MIT"
SHAREBOX_ENGINE = "modular"
inherit sharebox-image
IMAGE_INSTALL += "packagegroup-sharebox-frontend packagegroup-sharebox-engine-modular"
```

`sharebox-image.bbclass` adds `packagegroup-sharebox-base` and
`sharebox-config-${SHAREBOX_ENGINE}` itself.

- `packagegroup-sharebox-base`: systemd, networkd config, hostapd, dnsmasq,
  nftables, sharebox-config (common part), usb-automount, firmware, kernel
  modules, and if `SHAREBOX_UPDATES = "1"`: `rauc sharebox-update
  sharebox-healthcheck`.
- `sharebox-storage.bbclass` (inherited by `sharebox-image.bbclass`) adds
  `sharebox-storage` and, with updates, `kernel-image` itself.
- `packagegroup-sharebox-frontend`: lighttpd and its modules, captive-portal,
  status CGI. Not installed when an engine serves port 80 itself.

## Network

- `wlan0` static `192.168.77.1/24` (`SHAREBOX_IPV4`), name `sharebox.lan`
  (`SHAREBOX_HOSTNAME`). Open network, `ap_isolate=1`.
- Only tcp/80, udp+tcp/53, udp/67 are reachable from `wlan0`.
- Every engine that sits behind lighttpd listens on `127.0.0.1` only:

| Service | Port | lighttpd path |
| --- | --- | --- |
| dufs (public share, modular) | 5000 | `/files/` |
| dufs read-only (library, full) | 5001 | `/files/` (library) or `/files/` + `/upload/` (full) |
| ergo websocket | 8097 | `/socket` |
| gamja (static) | - | `/chat/` |
| sriracha | 8080 | `/forum/` |
| kiwix-serve | 8081 | `/wiki/` |

## lighttpd

- Main config `/etc/lighttpd/lighttpd.conf` (from the lighttpd bbappend) ends
  with `include "/etc/lighttpd/conf.d/*.conf"` and
  `include "/run/sharebox/lighttpd-runtime.conf"`.
- Each engine recipe ships its lighttpd snippet in a `${PN}-lighttpd` package
  as `/etc/lighttpd/conf.d/50-<name>.conf`, pulled in by its
  `packagegroup-sharebox-engine-*`. Snippets use only `mod_proxy`,
  `mod_redirect`, `mod_rewrite`, `mod_setenv`, `mod_webdav`, `mod_cgi`,
  `mod_staticfile`, `mod_indexfile`, `mod_access`. Snippets must not load
  modules: `server.modules` is set once in the main config.
- Document root: `/usr/share/sharebox/www` (home pages, one directory per
  language, `/en/` always present).

## Runtime configuration

- Build time values: `SHAREBOX_*` variables, baked by `sharebox-config` into
  `/usr/lib/sharebox/defaults.conf`.
- Run time overrides: `/data/config/sharebox.conf` (`key=value`: `ssid=`,
  `lang=`, `country=`, `channel=`, `band=`, `upload_max=`). A USB stick may
  provide `sharebox/sharebox.conf`.
- `sharebox-setup.service` (oneshot, `RemainAfterExit=yes`, POSIX shell, no
  interpreter beyond busybox/sh) merges both and writes into `/run/sharebox/`:
  - `env`: `SHAREBOX_SSID`, `SHAREBOX_LANG`, `SHAREBOX_COUNTRY`,
    `SHAREBOX_CHANNEL`, `SHAREBOX_BAND`, `SHAREBOX_UPLOAD_MAX` (bytes, `0`
    disables uploads), `SHAREBOX_HOSTNAME`, `SHAREBOX_ADDR` (address without
    prefix), `SHAREBOX_ENGINE`, `SHAREBOX_UPDATES`, `SHAREBOX_CAPTIVE_MODE`.
  - `hostapd.conf`, `dnsmasq.conf`, `lighttpd-runtime.conf`,
    `warnings` (one line per warning, shown on `/status`).
- Every service unit of the layer uses:
  `After=sharebox-setup.service`, `Requires=sharebox-setup.service`,
  `EnvironmentFile=/run/sharebox/env`.

## Users and data

- Common unprivileged user, created with the same parameters by every recipe
  that needs it:
  `USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data --shell /sbin/nologin --user-group sharebox"`.
- Service-specific users: `ergo`, `kiwix` (same style), `www` for lighttpd
  (oe-core default user of the lighttpd recipe is kept if it already exists).
- `/data` is the persistent ext4 partition. Its tree is created by
  `systemd-tmpfiles` (`sharebox-config` ships `/usr/lib/tmpfiles.d/sharebox.conf`):
  `/data/share` (public files), `/data/share/upload` (anonymous uploads,
  owner `sharebox`), `/data/chat` (owner `ergo`), `/data/forum`, `/data/zim`
  (owner `kiwix`), `/data/config`. Reserved for the storage lot:
  `/data/overlay/` (upper layers of `/etc` and `/var`, created by the
  preinit), `/data/rauc/` (RAUC state), `/data/.sharebox-grown`,
  `/data/.sharebox-data-fallback`. `/data/var` is not used.
- USB sticks mount read-only under `/media/usb-<label>`; `/data/share/usb`
  links to the most recent one.

## Storage

Details and rationale: `docs/updates.md`.

- Root filesystem: erofs (lz4hc), mounted read-only (`rootfstype=erofs ro`).
  Nothing may write to `/usr`, `/opt`, `/srv` or `/` at run time.
- `/etc` and `/var` are overlays whose upper layers are on `/data`
  (`/data/overlay/{etc,var}`), mounted by the preinit before systemd:
  they are writable and persistent. `/var/log` and `/var/tmp` are volatile
  (tmpfs). Recipes must not rely on `/etc` changes made at run time being
  replaced by a newer image: run-time settings go to `/data/config`.
- `/data` is mounted before systemd starts (fstab entry present, so
  `RequiresMountsFor=/data` works). If it cannot be mounted it is a 64M tmpfs
  and `/data/.sharebox-data-fallback` exists (the `/status` CGI may show a
  warning).
- Partition layout (msdos), from `conf/distro/include/sharebox-storage.inc`:

| `SHAREBOX_UPDATES` | p1 | p2 | p3 | p4 |
| --- | --- | --- | --- | --- |
| `1` | boot (vfat, mounted on `/boot` for `uboot.env`) | rootfs A | rootfs B | data |
| `0` | boot (not mounted) | rootfs | data | - |

- `IMAGE_FSTYPES = "erofs wic.gz wic.bmap"`.

## Updates

Only when `SHAREBOX_UPDATES = "1"` (`rauc` in `DISTRO_FEATURES`). Packages:
`rauc`, `sharebox-update` (USB hook, install command and units),
`sharebox-healthcheck`. Bundles: `sharebox-bundle-<engine>`.

### USB hook

`/usr/lib/sharebox/usb-hooks.d/50-rauc <mount point>` (run as root by
`sharebox-usb-scan.service`, which needs `/run/sharebox` writable and
`AF_UNIX` allowed) looks for `<mount point>/sharebox/*.raucb` (last one in
name order), runs `rauc info` (signature against the keyring) and checks the
compatible string. It writes `/run/sharebox/update-candidate`.

### Files read by the `/status` CGI

All are `key=value` lines, mode 0644, replaced atomically, absent when there
is nothing to report. Values are single-line and limited to
`[A-Za-z0-9 ._:+/@(),=-]` (200 characters), but the CGI must still
HTML-escape them.

`/run/sharebox/update-candidate`:

| Key | Meaning |
| --- | --- |
| `state` | `ready` (verified, can be installed) or `invalid` (refused) |
| `file` | absolute path of the bundle on the stick |
| `name` | bundle file name (the `bundle` form field, `@@BUNDLE@@`) |
| `version` | bundle version (`DISTRO_VERSION` of the new image), `ready` only |
| `description`, `build`, `compatible` | from the bundle manifest, `ready` only |
| `current` | running version (`VERSION_ID` of `/etc/os-release`) |
| `error` | why the bundle was refused, `invalid` only |
| `time` | Unix time of the check |

Show the install section only when `SHAREBOX_UPDATES = "1"`, `state=ready`
and `file` still exists (the stick may have been removed). An `invalid`
candidate may be shown as an error.

`/run/sharebox/update-status`:

| Key | Meaning |
| --- | --- |
| `state` | `installing`, `failed`, `rebooting`, `rolling-back`, `installed`, `rolled-back` |
| `message` | English sentence for the log or the page (RAUC error text for `failed`) |
| `version` | version being or having been installed |
| `time` | Unix time |

### Install command

On `POST /status` with `action=install`, the CGI runs

```
/usr/lib/sharebox/sharebox-install-update "<bundle field>"
```

as its own unprivileged user. The argument is only compared with the
candidate's `name`, never used as a path. The command prints one English
line and exits with 0 (request queued: show `status-result-ok`), 1 (no
verified update, or the candidate changed: show `status-result-error` with
the printed line) or 2 (internal error, same). Queuing writes
`/run/sharebox-update/request` (directory mode 1733, created by
tmpfiles), so the front end unit needs
`ReadWritePaths=/run/sharebox-update`. `sharebox-update-install.path` then
starts `sharebox-update-install.service` (root), which installs with
`rauc install`, writes `update-status` and reboots. Subsequent page loads
show `update-status`.

### Health check

`sharebox-healthcheck.service` commits the booted slot (`rauc status
mark-good`) once `hostapd.service`, `dnsmasq.service` are active and a
socket listens on TCP port 80, and rolls back a freshly installed slot that
does not get there within 180 s. It may append one line to
`/run/sharebox/warnings`.

## systemd unit hardening

Every unit shipped by the layer carries at least:

```
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
UMask=0077
```

plus `User=`, `CapabilityBoundingSet=` / `AmbientCapabilities=` limited to
what the service needs, `RestrictAddressFamilies=`, `IPAddressDeny=any` with
`IPAddressAllow=localhost` for localhost-only services, and explicit
`ReadWritePaths=` / `ReadOnlyPaths=`. Target score: `systemd-analyze security`
below 3.0. (Go binaries may need `MemoryDenyWriteExecute=yes` dropped only if
proven necessary; document it in the unit.)

## Recipe rules

- `SRCREV` pinned to a tag commit, never `AUTOREV`; `SRC_URI` in https with
  `;protocol=https;branch=<branch>` (or `nobranch=1` for tags).
- `LICENSE` is an exact SPDX identifier, `LIC_FILES_CHKSUM` on the upstream file.
- Go recipes: `inherit go-mod go-mod-update-modules`, generated
  `<pn>-go-mods.inc` and `<pn>-licenses.inc` committed, `CGO_ENABLED = "0"`
  where possible, `GOBUILDFLAGS:append = " -trimpath"`.
- Rust recipes: `inherit cargo cargo-update-recipe-crates`, generated
  `<pn>-crates.inc` committed.
- No `-native` Node.js, Python or Perl beyond what oe-core already uses.
- All text (code, comments, docs, commit messages) in English.
