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
| `recipes-support/{usb-automount,rauc,sharebox-healthcheck}` | USB sticks, updates |
| `recipes-kernel/linux/` | `linux-raspberrypi` bbappend and config fragments |
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
  modules, rauc (if `SHAREBOX_UPDATES = "1"`).
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
| ergo plain IRC (local tools only) | 6667 | - |
| gamja (static) | - | `/chat/` |
| forum (reserved, not packaged, see `docs/deviations.md`) | 8080 | `/forum/` |
| kiwix-serve | 8081 | `/wiki/` |

## lighttpd

- Main config `/etc/lighttpd/lighttpd.conf` (from the lighttpd bbappend)
  includes `/run/sharebox/lighttpd-runtime.conf` first, then
  `/etc/lighttpd/conf.d/*.conf` at the end, so that snippets can use the
  runtime variables: `var.sharebox_hostname`, `var.sharebox_addr`,
  `var.sharebox_host_regex` (matches the box name or address in the Host
  header), `var.sharebox_lang` (default page language),
  `var.sharebox_upload_max` (bytes, string). The runtime file also sets
  `server.max-request-size` and the Accept-Language negotiation of `/`.
- Each engine recipe ships its lighttpd snippet in a `${PN}-lighttpd` package
  as `/etc/lighttpd/conf.d/50-<name>.conf`, pulled in by its
  `packagegroup-sharebox-engine-*`. Snippets use only `mod_proxy`,
  `mod_redirect`, `mod_rewrite`, `mod_setenv`, `mod_webdav`, `mod_cgi`,
  `mod_alias`, `mod_staticfile`, `mod_indexfile`, `mod_access`. Snippets must
  not load modules: `server.modules` is set once in the main config.
  Built-in modules such as `mod_setenv`, `mod_alias`, `mod_redirect` must be
  listed there too; `mod_indexfile` comes before `mod_alias`.
  `10-captive.conf` (captive-portal) comes first.
- Global headers use `setenv.set-response-header` (nosniff, frame options,
  referrer policy). A snippet that sets it in a conditional replaces the
  global list and must repeat `X-Content-Type-Options: nosniff`.
- `/files/` and `/upload/` responses of active types (html, svg, js, ...) get
  `Content-Disposition: attachment` and `Content-Security-Policy: sandbox`.
- `server.stream-request-body = 2`: uploads are streamed to the engines.
- Snippets append with `+=` to shared settings (`url.redirect`,
  `alias.url`, `setenv.add-response-header`) so that they compose.
- WebSocket proxying (`/socket`): `proxy.header = ( "upgrade" => "enable" )`
  inside the conditional; large transfers (`/files/`) use
  `server.stream-request-body = 2` and `server.stream-response-body = 2`.

Snippets of the modular engine:

| Package | File | Content |
| --- | --- | --- |
| `dufs-lighttpd` | `50-dufs.conf` | `/files/` → `127.0.0.1:5000` (streamed, `nosniff`), modular |
| `dufs-ro-lighttpd` | `50-dufs-ro.conf` | `/files/` → `127.0.0.1:5001`, library and full |
| `dufs-upload-lighttpd` | `50-dufs-upload.conf` | `/upload/` → `127.0.0.1:5000`, full |
| `ergo-lighttpd` | `50-ergo.conf` | `/socket` → `127.0.0.1:8097` (WebSocket, 600 s idle) |
| `gamja-lighttpd` | `50-gamja.conf` | `/chat/` → `/usr/share/gamja/` (`alias.url`) |

- Document root: `/usr/share/sharebox/www` (home pages, one directory per
  language, `/en/` always present, `/style.css`). `/` on the box host is
  redirected (302) to `/<lang>/`: first Accept-Language tag, exact directory,
  then `i18n/lang-aliases.txt`, then without the last subtag, then
  `SHAREBOX_LANG`, then `en`.
- `/status`: shell CGI `/usr/lib/sharebox/cgi-bin/status`
  (`sharebox-config-status`), templates in
  `/usr/share/sharebox/templates/<lang>/`.
- The engine home page: `sharebox-config-<engine>` ships
  `www/<lang>/index-<engine>.html` and links `www/<lang>/index.html` to it at
  rootfs time (the engine packages are mutually exclusive).

## Captive portal

- `captive-portal` ships `/usr/share/captive-portal/{popup,silent}.conf`;
  `sharebox-setup` writes `/run/sharebox/captive.conf` (an include of the
  mode selected by `SHAREBOX_CAPTIVE_MODE` / `captive_mode=`), included by
  `/etc/lighttpd/conf.d/10-captive.conf`.
- Engines that serve port 80 themselves (luffy, shareboxx) must implement
  the same behaviour and may read `SHAREBOX_CAPTIVE_MODE` from the env file.

## Firewall

- `/etc/nftables/sharebox.nft` (nftables bbappend), loaded by
  `nftables.service` before hostapd, dnsmasq and lighttpd. It ends with
  `include "/etc/nftables.d/*.nft"`: extra rules are added to the existing
  chains with `table inet sharebox { chain input { ... } }`
  (e.g. `sharebox-config-devaccess` opens SSH on non-wlan0 interfaces).

## Runtime configuration

- Build time values: `SHAREBOX_*` variables, baked by `sharebox-config` into
  `/usr/lib/sharebox/defaults.conf` (same `key=value` format; also
  `hostname=`, `ipv4=`, `engine=`, `updates=`, `version=`).
- Run time overrides: `/data/config/sharebox.conf` (`key=value`: `ssid=`,
  `lang=`, `country=`, `channel=`, `band=` (`2.4` or `5`), `upload_max=`
  (`500M`, `2G`, `0`), `captive_mode=` (`popup` or `silent`)). The file is
  parsed, never sourced; invalid values are ignored with a warning. A USB
  stick may provide `sharebox/sharebox.conf`.
- `sharebox-setup.service` (oneshot, `RemainAfterExit=yes`, POSIX shell, no
  interpreter beyond busybox/sh) merges both and writes into `/run/sharebox/`:
  - `env`: `SHAREBOX_SSID`, `SHAREBOX_LANG`, `SHAREBOX_COUNTRY`,
    `SHAREBOX_CHANNEL`, `SHAREBOX_BAND`, `SHAREBOX_UPLOAD_MAX` (bytes, `0`
    disables uploads), `SHAREBOX_HOSTNAME`, `SHAREBOX_ADDR` (address without
    prefix), `SHAREBOX_PREFIX`, `SHAREBOX_ENGINE`, `SHAREBOX_UPDATES`,
    `SHAREBOX_CAPTIVE_MODE`, `SHAREBOX_VERSION`. Values are double-quoted
    with backslash, double quote, dollar and backquote escaped (valid for
    systemd and `sh`).
  - `hostapd.conf`, `dnsmasq.conf`, `lighttpd-runtime.conf`, `captive.conf`,
    `warnings` (one line per warning, shown on `/status`).
  - then runs every executable `/usr/lib/sharebox/setup.d/*` with the env
    exported (engines generate their own runtime files there, e.g.
    luffy's `piratebox.conf`, into `/run/sharebox/`).
- Regulatory rules: no country means no `country_code` (world domain),
  2.4 GHz only, channels 1-11; `band=5` without a country (or on a board
  without 5 GHz) stays on 2.4 GHz with a warning; an out-of-range channel is
  reset to 6 (2.4 GHz) or 36 (5 GHz) with a warning. 5 GHz uses 36-48 or
  149-165, HT40, no VHT80.
- Language: `lang=` > `SHAREBOX_LANG` > single official language of the
  country (`country-lang.csv`) > `en`. SSID: `ssid=` > `SHAREBOX_SSID` >
  `ssid-<lang>.txt` > `ssid-en.txt` (32 bytes max).
- Restarting `sharebox-setup.service` restarts every unit that `Requires=` it
  (hostapd, dnsmasq, lighttpd, engines): that is how a new configuration is
  applied.
- Every service unit of the layer uses:
  `After=sharebox-setup.service`, `Requires=sharebox-setup.service`,
  `EnvironmentFile=/run/sharebox/env`.

## Data files of sharebox-config (i18n lot)

Under `recipes-core/sharebox-config/files/`, installed as whole directories:

- `i18n/languages.txt`: `code<TAB>ltr|rtl<TAB>native name`.
- `i18n/ssid-<code>.txt`: one line, the full SSID (`ShareBox - <slogan>`).
- `i18n/country-lang.csv`: header `country,lang`; `lang` empty when the
  country has several official languages.
- `i18n/lang-aliases.txt`: `alias<TAB>code` for browser tags.
- `www/style.css`, `www/<code>/how-it-works.html` (final),
  `www/<code>/index.html.in` (`@@ENGINE_LINKS@@` alone on a line, replaced
  by `www/<code>/engine-<engine>.html`; cards with `optional-forum` or
  `optional-upload` dropped: always for the forum (no forum engine), when
  `SHAREBOX_UPLOAD_MAX = "0"` for uploads).
- `/status` templates: `status.html.in` (`@@CLIENTS@@`, `@@DISK_FREE@@`,
  `@@VERSION@@`, `@@WARNINGS@@`, `@@UPDATE_RESULT@@`, `@@UPDATE_SECTION@@`),
  `status-update.html.in` (`@@BUNDLE@@`), `status-result-ok.html`,
  `status-result-error.html.in` (`@@ERROR@@`).

## Updates from /status (storage lot interface)

- The storage lot writes the absolute path of a bundle it verified
  (`rauc info`) to `/run/sharebox/update-bundle`; `/status` then shows the
  install form (only when `SHAREBOX_UPDATES = "1"`).
- A confirmed POST writes that same path (never a client supplied one) to
  `/run/sharebox/requests/install` (directory `root:www 0730`); the storage
  lot watches it (path unit) and installs.
- The result is reported in `/run/sharebox/update-result`: `ok` or
  `error: <message>`.

## USB sticks

- udev rule `99-sharebox-usb.rules` calls `/usr/lib/sharebox/usb-mount`,
  which runs `systemd-mount --no-block --automount=yes --collect
  --options=ro,nosuid,nodev,noexec` on `/media/usb-<label>` (`/media` is a
  tmpfs, `media.mount`), then restarts `sharebox-usb-scan.service`.
- `sharebox-usb-scan` links `/data/share/usb` to the newest stick (its
  `share/` directory if present), imports `sharebox/sharebox.conf` into
  `/data/config` and restarts `sharebox-setup.service` when it changed, then
  runs every executable `/usr/lib/sharebox/usb-hooks.d/*` with the active
  mount points as arguments (none when the last stick is removed). The
  hooks run in the scan service sandbox (no network, no capability,
  `/media` read-only; `/data/share`, `/data/config`, `/run/sharebox`
  writable); a hook needing more ships a drop-in for the service.

## Users and data

- Common unprivileged user, created with the same parameters by every recipe
  that needs it:
  `USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data --shell /sbin/nologin --user-group sharebox"`.
- Service-specific users: `ergo`, `kiwix` (same style), `www` for lighttpd
  (created by the lighttpd bbappend), `dnsmasq` (dnsmasq bbappend).
- `/data` is the persistent ext4 partition. Its tree is created by
  `systemd-tmpfiles` (`sharebox-config` ships `/usr/lib/tmpfiles.d/sharebox.conf`):
  `/data/share` (public files), `/data/share/upload` (anonymous uploads,
  owner `sharebox`), `/data/forum` (owner `sharebox`), `/data/config`,
  `/data/var`. Directories owned by an engine user are created by that
  engine recipe's own tmpfiles file (the user may not exist in other
  images): `/data/chat` (owner `ergo`), `/data/zim` (owner `kiwix`).
- USB sticks mount read-only under `/media/usb-<label>`; `/data/share/usb`
  links to the most recent one.
- Engines that serve port 80 themselves keep their private state in
  `/data/<engine>` (owner `sharebox`, created by the engine recipe's own
  tmpfiles snippet): `/data/luffy`, `/data/shareboxx`. They write uploads
  only to `/data/share/upload`.
- luffy reads `/run/sharebox/luffy/piratebox.conf`, generated by the luffy
  recipe itself (`ExecStartPre=`) from `/run/sharebox/env`;
  `/etc/piratebox/piratebox.conf`, if present, is only sourced as site
  customisation (see `docs/deviations.md`).

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
  where possible, `GOBUILDFLAGS:append = " -trimpath"`. Exception: when
  upstream commits a complete `vendor/` (ergo), build with `-mod=vendor`,
  skip `go-mod-update-modules` and commit only `<pn>-licenses.inc`.
- Rust recipes: `inherit cargo cargo-update-recipe-crates`, generated
  `<pn>-crates.inc` committed.
- No `-native` Node.js, Python or Perl beyond what oe-core already uses.
- All text (code, comments, docs, commit messages) in English.

