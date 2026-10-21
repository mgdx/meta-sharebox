# Deviations from the specification

## Modular engine

### Sriracha (forum) is not packaged

The specification points at `github.com/jacobhq/sriracha` (Go, LGPL-3.0,
SQLite) as an optional forum. That repository does not exist. The only
matching project is Sriracha by Trevor Slocum
(`codeberg.org/tslocum/sriracha`, v2.2.0, Go, LGPL-3.0, no CGO), an
imageboard and forum server, but it does not fit the box:

- PostgreSQL is its only supported database. Its pure Go SQLite driver
  (modernc.org/sqlite) is only used to import and export posts. Running a
  PostgreSQL server on a Raspberry Pi box is far outside the RAM and image
  size budget of the `modular` and `full` images.
- It must be served at `/`: running it under a sub-path such as `/forum/`
  is explicitly unsupported upstream.
- It creates a default super-administrator account (`admin`/`admin`) that
  must be changed through the web interface, which is reachable by everyone
  on the open network.

`packagegroup-sharebox-engine-modular` therefore installs no forum and there
is no `SHAREBOX_FORUM` switch. The `full` image does not get a forum either.
Port 8080 and `/forum/` stay reserved in `docs/ARCHITECTURE.md` for a later
forum engine.

### Ergo: vendored modules instead of generated go-mods.inc

Ergo commits all its Go dependencies in `vendor/` (with
`vendor/modules.txt`). The recipe builds with `-mod=vendor` and does not
inherit `go-mod-update-modules`: there is no `ergo-go-mods.inc`, nothing is
fetched with `gomod://`. `ergo-licenses.inc` lists the licenses of the
vendored modules actually linked into the binary; it was produced with
`go list -deps -tags sqlite .` and `oe.license_finder`, unknown entries
checked by hand (see the header of the file).

### Ergo: SQLite history without CGO

Ergo 2.19.1 supports SQLite for persistent history with the pure Go driver
modernc.org/sqlite (build tag `sqlite`), so the binary is built with
`CGO_ENABLED=0`. History of `#sharebox` is stored in `/data/chat/ergo.db`
(as in the specification), server state in `/data/chat/ircd.db` (buntdb).
Direct messages are never written to disk, history expires after one week.

There are no accounts (registration and authentication disabled), so
`#sharebox` cannot be registered and Ergo has no "always-on" channel:
every client auto-joins `#sharebox` (`channels.auto-join`) and the
persistent history (`unregistered-channels: true`) is replayed by gamja on
join. The `i18n` build tag is left out: Ergo server messages are in
English.

### gamja: no prebuilt dist/

gamja release tarballs (sr.ht and Codeberg, latest tag `v1.0.0-beta.11`,
the project moved to `codeberg.org/emersion/gamja`) contain the source tree
only, without `dist/`. No reliable prebuilt artifact is published (the CI
artifacts expire). gamja does not need its Parcel build though: the
sources are native ES modules that only import
`node_modules/{preact,htm,linkifyjs}/dist/*.js`. The recipe fetches the
tagged source from git and the three npm registry tarballs pinned to the
versions of the upstream `package-lock.json` (SHA-256 in the recipe), and
installs only the files the browser loads. No Node.js, no vendored binary
blob. `LICENSE` is `AGPL-3.0-only & MIT & Apache-2.0` (gamja, preact and
linkifyjs, htm).

The recipe is `gamja_git.bb` with `PV = "1.0.0~beta.11"` (the `~` keeps
the pre-release ordering below a future 1.0.0).

### gamja: relative WebSocket URL

`config.json` uses `"url": "/socket"` instead of `ws://sharebox.lan/socket`.
gamja turns the path into a WebSocket URL on the host the page was loaded
from, so it keeps working when `SHAREBOX_HOSTNAME` is changed or when the
box is reached by its IP address.

### gamja is served with mod_alias

The `/chat/` snippet uses `alias.url` to map `/chat/` to `/usr/share/gamja/`
(the specification install path), so `mod_alias` is added to the modules
allowed in snippets (`docs/ARCHITECTURE.md`). It is built into lighttpd
1.4.82 but must be listed in `server.modules`.

### dufs packaging

One recipe, six packages, selected per image:

| Package | Content | modular | library | full |
| --- | --- | --- | --- | --- |
| `dufs` | binary, `sharebox` user | x | x | x |
| `dufs-rw` | `dufs.service`, writable, 127.0.0.1:5000 | x | | x |
| `dufs-ro` | `dufs-ro.service`, read-only, 127.0.0.1:5001 | | x | x |
| `dufs-lighttpd` | `/files/` → 5000 | x | | |
| `dufs-ro-lighttpd` | `/files/` → 5001 | | x | x |
| `dufs-upload-lighttpd` | `/upload/` → 5000 | | | x |

`dufs-lighttpd` and `dufs-ro-lighttpd` claim the same URL and conflict
(`RCONFLICTS`). `packagegroup-sharebox-engine-modular` only recommends
`dufs-lighttpd`, so the full image drops it with `BAD_RECOMMENDATIONS` and
installs `dufs-upload-lighttpd`. `dufs.service` reads `SHAREBOX_ENGINE` from
`/run/sharebox/env`: with `full` it serves only `/data/share/upload` (all
writable) under `--path-prefix /upload`, otherwise the whole share under
`/files` with writes restricted to `upload/`.

dufs has no upload size limit: lighttpd `server.max-request-size` is the
only limit. `dufs.service` (package `dufs-rw`) starts dufs through `/usr/libexec/dufs/dufs-start`
(POSIX shell) so that `--allow-upload` is dropped when
`SHAREBOX_UPLOAD_MAX` is `0`. Anonymous users may write only under
`/data/share/upload` (`--auth '@/,/upload:rw'`); without `--allow-delete`
dufs refuses deletes, moves and overwrites of non-empty files but still
accepts resumed uploads (PATCH) of a partial file. `--allow-symlink` is set
so that the `/data/share/usb` link to the USB stick can be followed.

## Library engine

### Versions

| Component | Specification | Layer | Reason |
| --- | --- | --- | --- |
| libzim | 9.4.0 | 9.8.2 | Latest stable release (August 2026). libkiwix 14.2.1 requires libzim >= 9.4.0, < 10. |
| libkiwix | 14.1.1 | 14.2.1 | Latest stable release (May 2026), same API major. kiwix-tools 3.8.2 requires libkiwix >= 14.1.0, < 15. |
| kiwix-tools | 3.8.2 | 3.8.2 | Unchanged (latest release). |
| xapian-core | from meta-oe | 1.4.32, in this layer | Not packaged in Wrynose: `recipes-kiwix/xapian-core/` (autotools, GPL-2.0-or-later). Latest 1.4.x stable. |
| kainjow-mustache | - | 4.1 | Header-only dependency of libkiwix ("Mustache 4.1 or above"), BSL-1.0. |
| docopt.cpp | not listed | meta-oe | Build dependency of kiwix-tools (command line parsing), already in meta-oe. |

### Xapian cannot be disabled on small machines

The specification asks for a `xapian` `PACKAGECONFIG` enabled on Pi 4 and 5
and disabled on Zero 2 W and Pi 3. libzim builds without Xapian
(`-Dwith_xapian=false`), but libkiwix 14 refuses to: its `meson.build` checks
`LIBZIM_WITH_XAPIAN` and stops with "Xapian support is mandatory". kiwix-serve
therefore always links against Xapian, on every machine.

Decision:

- libzim keeps `PACKAGECONFIG[xapian]`, enabled by default everywhere, with a
  comment that it must stay on as long as libkiwix is built. There are no
  machine overrides.
- Xapian mostly costs memory when a full-text search or a title suggestion is
  run (the indexes embedded in the ZIM file are opened on demand); plain
  browsing does not load them.
- The RAM risk on small machines is contained by systemd instead:
  `MemoryMax=` of `kiwix-serve.service` is 256M on `raspberrypi0-2w-64`,
  384M on `raspberrypi3-64`, 512M by default (Pi 4) and 1G on `raspberrypi5`
  (`KIWIX_SERVE_MEMORY_MAX` in the kiwix-tools recipe, overridable). A search
  that exceeds it kills kiwix-serve, which systemd restarts.
- `kiwix-search` is built (Xapian is there anyway) but packaged separately and
  not installed by any packagegroup.

### kiwix-serve command line

The unit runs the specified command and adds:

- `--urlRootLocation /wiki`: kiwix-serve generates its links under `/wiki/`,
  so lighttpd proxies the path unchanged (no rewrite).
- `--blockexternal`: the box is offline; external links show a notice page
  instead of failing.

### Library file

`/data/zim/library.xml` is rebuilt by `kiwix-library-update` (oneshot
service, user `kiwix`, the only unit allowed to write `/data/zim`), at boot
and from the USB hook `/usr/lib/sharebox/usb-hooks.d/60-kiwix`, which
restarts that service rather than running the script as root. ZIM files are
added one at a time because kiwix-manage aborts the whole run on the first
invalid file. When no ZIM file is found an empty library is written, so
kiwix-serve still starts (it only warns about an empty library).

### Packages

The kiwix-tools recipe produces `kiwix-serve`, `kiwix-manage` (with
`kiwix-library-update`, its unit and the USB hook), `kiwix-search` and
`kiwix-tools-lighttpd` (`/etc/lighttpd/conf.d/50-kiwix.conf`). Because the
memory limit is machine specific, kiwix-tools is `MACHINE_ARCH`.

libkiwix installs the Python build helpers `kiwix-compile-resources` and
`kiwix-compile-i18n`; they are removed from the target packages (no Python on
ShareBox images).

### Full image

- Restricted to `raspberrypi4-64`, `raspberrypi5` and the generic
  `raspberrypi-armv8` (`COMPATIBLE_MACHINE`), as the "full" section of the
  specification reserves it to Pi 4 and 5.
- `SHAREBOX_FORUM = "1"` is set in the image, and the forum packages
  (`SHAREBOX_FORUM_PACKAGES`, default `sriracha sriracha-lighttpd`) are added
  to `IMAGE_INSTALL` by the image itself, because a variable set in an image
  recipe is not visible to the packagegroup recipes.
- `SHAREBOX_DLNA ?= "0"` adds meta-multimedia `minidlna` when set to `1`
  (parse error if meta-multimedia is absent). Its configuration and the
  firewall ports (tcp/8200, udp/1900) are not handled yet.
- engine-modular and engine-library both bring a dufs instance. In the full
  image `/files/` must point to the read-only instance (5001) and `/upload/`
  to the writable one (5000), see `docs/ARCHITECTURE.md`; the lighttpd
  snippets of the dufs recipe have to handle that case.

## Luffy (classic engine)

Upstream: <https://github.com/et0and/luffy>, GPL-3.0 (`GPL-3.0-only` in the
recipe, upstream states "GPLv3"), Go standard library only (no module
dependency). No release tag exists: the recipe pins commit
`9523301d7ad2cedbf7a735b328f3a2d3ef678e66` (2026-09-19) with
`PV = "1.0.0+git"` (version from upstream's Makefile).

- **Configuration file location.** The specification has `sharebox-config`
  write `/etc/piratebox/piratebox.conf`. The luffy recipe instead generates
  `/run/sharebox/luffy/piratebox.conf` at every start (`ExecStartPre=`
  `luffy-gen-config`, run as `sharebox`) from `/run/sharebox/env`
  (`SHAREBOX_HOSTNAME` -> `HOST`, `SHAREBOX_ADDR` -> `IP`/`NET`/`IP_SHORT`,
  `SHAREBOX_UPLOAD_MAX` -> `UPLOAD_MAX_SIZE_MB` and `DROOPY_ENABLED`). If
  `/etc/piratebox/piratebox.conf` exists (for example written by
  `sharebox-config`) it is sourced as site customisation, but the keys that
  must match the sandbox (paths, ports, network management) are forced
  after it. luffy thus depends on nothing but `/run/sharebox/env`.
- **Data layout.** `PIRATEBOX_FOLDER=/data/luffy` (chat, forum, web content,
  created by `luffy.tmpfiles`), `UPLOADFOLDER=/data/share/upload`, and the
  `/Shared` listing shows the whole `/data/share` (new `DIRLIST_FOLDER` key,
  see the patch below).
- **`luffy serve`, not `luffy start`.** luffy can manage the interface,
  hostapd, dnsmasq and iptables; in ShareBox the base system owns those, so
  the unit runs the web server only.
- **Uploads on port 80.** Upstream serves the droopy upload form on a second
  port (8080) and the start page iframe points to `http://luffy.lan:8080`.
  The firewall only opens port 80, so the layer patch
  `0001-Serve-uploads-on-the-main-listener.patch` mounts the form under
  `/upload/` on the main listener and `DROOPY_PORT="0"` disables the second
  listener. To be proposed upstream.
- **Captive probes.** luffy always answers the probes as "Internet is
  available" (`/generate_204` -> 204, Apple `Success`): it behaves like
  `SHAREBOX_CAPTIVE_MODE=silent` whatever the setting (the specification
  already calls silent mode native to luffy). Popup mode is not available
  in the classic image.
- **`go-mod-update-modules`.** With no module dependency, the class would
  write `LICENSE += "& "` (invalid); `luffy-licenses.inc` and
  `luffy-go-mods.inc` are therefore kept by hand (both empty).
- **Unit.** `ReadWritePaths=/data/luffy /data/share/upload` rather than the
  whole `/data`. `AF_NETLINK` is allowed for `iw dev wlan0 station dump`
  (connected clients counter; `iw` is an `RRECOMMENDS`).

## Shareboxx

Upstream: <https://github.com/dividebysandwich/shareboxx>, GPL-2.0
(`GPL-2.0-only`), latest tag `v1.1.4` (2026-05-07, commit
`e216e16b730c19eefee36d8cec1f0740458d3aea`), as in the specification.

### Decision on the wasm32 open point: option (b)

Leptos needs two builds: the server (`ssr` feature, target binary) and the
client (`hydrate` feature, `wasm32-unknown-unknown`, then `wasm-bindgen`
and, for the stylesheet, dart-sass). Option (a) would require adding a
wasm32 target to the Wrynose Rust toolchain (rust 1.94.1, its
`libstd-rs` and the rust target config only know Linux targets), a
`wasm-bindgen-cli-native` recipe pinned to the exact `wasm-bindgen` crate
version, `cargo-leptos-native`, and dart-sass, which is a Dart/Node.js
program that the specification forbids as `-native`. That is a lot of
toolchain work for 1 MB of portable assets.

Retained: **(b) with upstream release assets.** Upstream's release CI runs
`cargo leptos build --release` and publishes `.deb` packages whose
`/var/lib/shareboxx/site/` holds the client bundle (`pkg/shareboxx.wasm`,
`pkg/shareboxx.js`, `pkg/shareboxx.css`, images). Nothing binary is stored
in the layer:

- `shareboxx-web_1.1.4.bb` (allarch) fetches
  `shareboxx_1.1.4_arm64.deb` from the GitHub release (sha256 checked by the
  fetcher), unpacks only `site/`, checks every installed file against
  `files/shareboxx-web-1.1.4.sha256` and installs it in
  `/usr/share/shareboxx/site`. The server binary of the package is ignored.
- `shareboxx_1.1.4.bb` builds the server from the git tag with
  `cargo.bbclass`: `--no-default-features --features ssr --bin shareboxx`,
  `--release` (default profile, unwinding kept so that a panicking request
  does not abort the whole server).

### Keeping server and client in step

The client calls server functions at URLs computed at compile time, and
the hydration script must load the right file names:

1. **Cargo.lock.** Upstream does not commit a `Cargo.lock` (it is in
   `.gitignore`). The layer ships `files/Cargo.lock`, resolved with the
   registry as it was when the release was built:
   `cargo -Zunstable-options generate-lockfile --publish-time 2026-05-07T13:00:00Z`
   then `cargo update -p actix-http --precise 3.12.1`. Every crate version
   that appears in the panic paths of the upstream arm64 binary (98 crates)
   and of the upstream wasm bundle (35 crates: leptos 0.8.19, server_fn
   0.8.12, wasm-bindgen 0.2.121, ...) matches this lock file.
2. **Server function hash.** server_fn appends
   `xxh64(CARGO_MANIFEST_DIR + ":" + module_path)` to every endpoint. The
   bundle was built in `/home/runner/work/shareboxx/shareboxx`, giving
   `/api/<name>12246998792517303403`. The recipe exports
   `SERVER_FN_OVERRIDE_KEY = "/home/runner/work/shareboxx/shareboxx"`, which
   server_fn uses instead of `CARGO_MANIFEST_DIR`, so the server registers
   the same URLs (verified by computing the hash).
3. **Output name.** cargo-leptos exports `LEPTOS_OUTPUT_NAME` at compile
   time; without it Leptos would load `shareboxx_bg.wasm`. The recipe
   exports `LEPTOS_OUTPUT_NAME = "shareboxx"`.

### Regenerating for a new upstream version

1. Bump `PV`/`SRCREV` in `shareboxx_<ver>.bb` and rename both recipes.
2. Fetch the new `.deb`, update `SRC_URI[deb.sha256sum]`,
   `SRC_URI[license.sha256sum]` and `files/shareboxx-web-<ver>.sha256`
   (`sha256sum` of the files under `var/lib/shareboxx/site`).
3. Regenerate the lock file at the release time of the tag (see 1. above)
   with a nightly cargo, compare its versions with the crate paths found in
   the upstream binaries (`strings` on `usr/bin/shareboxx` and
   `pkg/shareboxx.wasm`, look for `index.crates.io-*/<crate>-<version>/`)
   and pin outliers with `cargo update --precise`.
4. `scripts/cargo-lock-to-crates-inc.py files/Cargo.lock shareboxx >
   shareboxx-crates.inc`.
5. Check that the hash in the wasm (`strings pkg/shareboxx.wasm | grep /api/`)
   still matches `SERVER_FN_OVERRIDE_KEY`; upstream CI paths may change.

### Other changes

- Layer patch `0001-Make-host-name-and-upload-limit-configurable.patch`:
  - upstream redirects every request whose host is not `shareboxx.lan`;
    the host name now comes from `SHAREBOXX_HOSTNAME` (unit: from
    `SHAREBOX_HOSTNAME`);
  - the multipart limit (hard coded 10 GiB) comes from
    `SHAREBOXX_UPLOAD_MAX` (unit: `SHAREBOX_UPLOAD_MAX` bytes, 0 rejects
    uploads);
  - **security fix**: `upload_path` and the file name were concatenated to
    `./files/` without checks, allowing `../` to write anywhere the service
    can write; they are now rejected if absolute or containing `..`;
  - `df --output=size,avail -B1` (GNU only) replaced by `df -P -k`, which
    busybox understands.
- Data: shareboxx works relative to its working directory
  `/data/shareboxx` (chat.json, stats.json, config.json, uploads.db);
  `./files` is a symlink to `/data/share/upload` (created by
  `shareboxx.tmpfiles`). The files shown by ShareBoxx are therefore the
  anonymous upload area, not the whole `/data/share` (which is root owned in
  the data layout); see open issues.
- Upstream's `.deb` postinst and `shareboxx-setup` (hostapd, dnsmasq,
  iptables) are not used.
- `LICENSE` of the server lists GPL-2.0-only and the licenses of the
  statically linked crates (audited from crates.io for the 380 crates of the
  lock file; for "MIT OR Apache-2.0" crates MIT is retained, being
  GPL-2.0 compatible): `MIT & BSD-3-Clause & BSL-1.0 & MPL-2.0 &
  Unicode-3.0 & Zlib & CC0-1.0`. Only the upstream `LICENSE` is checksummed.
- Machines: 64-bit only (`COMPATIBLE_MACHINE` on the image), as in the
  specification.
- Reproducibility: the client bundle is upstream's binary output; the
  server is built in Yocto and covered by the usual reproducibility checks.

## Base system (core lot)

### UART enabled whenever U-Boot is used

The specification asks for `ENABLE_UART = "0"` in production. With
`RPI_USE_U_BOOT = "1"` (required by RAUC), meta-raspberrypi's `rpi-config`
refuses `ENABLE_UART = "0"` on the Zero W, Pi 3, Pi 4 and 64-bit boards
(`rpi_0_w`, `rpi_3_32b`, `rpi_4_32b`, `rpi_arm64` U-Boot configurations):
U-Boot needs the UART to operate.

So the UART is electrically enabled (`enable_uart=1` in `config.txt`)
whenever U-Boot is used, which means always when `SHAREBOX_UPDATES = "1"`.
In production (`SHAREBOX_DEV = "0"`), nothing is attached to it:

- `CMDLINE_SERIAL = ""`: no `console=serial0` on the kernel command line.
  U-Boot passes the firmware's `cmdline.txt` bootargs through, so the kernel
  has no serial console either way.
- `SERIAL_CONSOLES = ""`: no serial getty (and the systemd getty generator
  has no serial console to attach to).
- U-Boot itself still prints on the UART and honours its boot delay; an
  attacker with physical access to the header is out of the threat model
  (physical access also gives the SD card).

With `SHAREBOX_UPDATES = "0"`, U-Boot is not used and `ENABLE_UART = "0"`.
The dev profile (`sharebox-dev`) enables the UART, the serial console and its
login.

### dnsmasq `bind-dynamic`

`bind-dynamic` instead of `bind-interfaces`: same listening set (wlan0 and
lo) but dnsmasq does not fail when wlan0 gets its address after it starts.

### PCI kept in the kernel

The specification disables PCI except on Pi 5. The Pi 4 (and CM4) USB
controller is a PCIe device, so PCI stays enabled on every machine.

### /status client count

`/status` counts the devices seen on wlan0 in the ARP table instead of
calling `hostapd_cli all_sta`: giving the web server access to the hostapd
control socket would let it reconfigure the access point.

### Kernel modules and module signing

The image still installs `kernel-modules` (from meta-raspberrypi's
`MACHINE_EXTRA_RRECOMMENDS`); trimming it to an explicit module list is a
footprint task for later. Module signing (`module.sig_enforce=1`) is not
configured yet.

### CVE databases and SPDX sources on developer builds

`sbom-cve-check` downloads the CVE databases (several GB) and
`SPDX_INCLUDE_SOURCES = "1"` makes SBOMs large. Both are on by default;
developer builds may set `SHAREBOX_CVE_CHECK = "0"` and
`SPDX_INCLUDE_SOURCES = "0"` in `local.conf`.

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
