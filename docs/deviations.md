# Deviations from the specification

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
