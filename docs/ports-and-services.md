# Ports and services

What runs on a ShareBox and what listens on the network, per image. It
describes the production distro (`sharebox`) built with the defaults
(`SHAREBOX_UPDATES = "1"`). The tables come from the unit files and
configuration of the layer; they are checked on a running box with
`ss -lntup` and `nmap` by `scripts/test-target.sh`.

## Network interfaces

| Interface | Configuration | Exposure |
| --- | --- | --- |
| `wlan0` | static `192.168.77.1/24` (`SHAREBOX_IPV4`), no IPv6 link-local address, no router advertisements; open access point (hostapd) | all clients |
| `lo` | loopback | local services only |
| `eth0` (when present) | not configured in production (no DHCP client); DHCP client in the dev distro | dev distro only |

## Firewall (all images)

`/etc/nftables/sharebox.nft`, table `inet sharebox` (IPv4 and IPv6):

| Chain | Policy | Rules |
| --- | --- | --- |
| `input` | drop | accept `lo`, established/related; drop invalid; from `wlan0`: accept udp 53, 67; accept new tcp 53, 80 (limit 50/s); **reject tcp 443 with a TCP reset**; accept ICMP echo (limit 10/s) |
| `forward` | drop | none: the box never routes |
| `prerouting` (nat) | accept | from `wlan0`, tcp 80 and udp/tcp 53 to any address are redirected to the box |

Expected `nmap -p- 192.168.77.1` result from a client: 53/tcp and 80/tcp
open, 443/tcp closed (reset), every other port filtered. UDP: 53 and 67.

Development distro only (`sharebox-config-devaccess`,
`/etc/nftables.d/50-sharebox-dev.nft`): on interfaces other than `wlan0`,
tcp 22 (SSH), ICMP echo, ICMPv6, udp 68 and 546 (DHCP clients). Never on
`wlan0`.

## Listening sockets per image

"All" means `0.0.0.0` (any address); the firewall restricts what is
reachable from `wlan0`.

| Process | Unit | User | Socket | base | classic | modular | shareboxx | library | full |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dnsmasq | `dnsmasq.service` | `dnsmasq` | udp+tcp 53 on `wlan0` and `lo` (`bind-dynamic`) | x | x | x | x | x | x |
| dnsmasq (DHCP) | `dnsmasq.service` | `dnsmasq` | udp 67 (all) | x | x | x | x | x | x |
| hostapd | `hostapd.service` | root | no IP socket (nl80211, raw 802.11 frames) | x | x | x | x | x | x |
| lighttpd | `lighttpd.service` | `www` | tcp 80 (all) | x | | x | | x | x |
| luffy | `luffy.service` | `sharebox` | tcp 80 (all) | | x | | | | |
| ShareBoxx | `shareboxx.service` | `sharebox` | tcp 80 (all, `LEPTOS_SITE_ADDR=0.0.0.0:80`) | | | | x | | |
| dufs (writable) | `dufs.service` | `sharebox` | tcp `127.0.0.1:5000` | | | x | | | x |
| dufs (read-only) | `dufs-ro.service` | `sharebox` | tcp `127.0.0.1:5001` | | | | | x | x |
| Ergo (WebSocket) | `ergo.service` | `ergo` | tcp `127.0.0.1:8097` | | | x | | | x |
| Ergo (plain IRC, local tools) | `ergo.service` | `ergo` | tcp `127.0.0.1:6667` | | | x | | | x |
| kiwix-serve | `kiwix-serve.service` | `kiwix` | tcp `127.0.0.1:8081` | | | | | x | x |

Development distro, in addition: dropbear (`dropbear.socket`), tcp 22 on
all addresses, public key authentication only; the firewall drops it on
`wlan0`. systemd-networkd runs a DHCP client (udp 68) on Ethernet.

Nothing else listens: systemd-resolved, timesyncd, hostnamed and the
syslog daemon are not built (`recipes-core/systemd/systemd_%.bbappend`),
and there is no SSH server in production.

## HTTP paths (images with lighttpd)

| Path | Served by | Images |
| --- | --- | --- |
| `/` → `/<lang>/` | static home pages, `Accept-Language` negotiation | base, modular, library, full |
| `/status` | shell CGI `/usr/lib/sharebox/cgi-bin/status` (user `www`) | base, modular, library, full |
| `/files/` | dufs 5000 (modular) or 5001 read-only (library, full) | modular, library, full |
| `/upload/` | dufs 5000, writable upload area | full |
| `/socket` | Ergo WebSocket 8097 | modular, full |
| `/chat/` | gamja static files | modular, full |
| `/wiki/` | kiwix-serve 8081 | library, full |
| any other host | captive portal: redirect (popup) or probe answers (silent) | base, modular, library, full |

In `classic` and `shareboxx`, the engine serves every path itself.

## Users

| User | Created by | Used by | Writable data |
| --- | --- | --- | --- |
| `root` | base-passwd | hostapd, sharebox-setup, nftables, usb-scan, healthcheck, update install, grow-data (all with reduced capability sets) | `/run/sharebox`, `/data/config`, `/data/rauc` |
| `www` | lighttpd bbappend | lighttpd and the `/status` CGI | `/run/sharebox/requests` (queue an update) |
| `dnsmasq` | dnsmasq bbappend | dnsmasq | `/run/dnsmasq` (leases) |
| `sharebox` | dufs, luffy, shareboxx recipes | dufs, luffy, ShareBoxx | `/data/share/upload`, `/data/luffy`, `/data/shareboxx` |
| `ergo` | ergo recipe | Ergo | `/data/chat` |
| `kiwix` | kiwix-tools recipe | kiwix-serve (read-only), kiwix-library-update | `/data/zim` (library file) |

No user has a password or a login shell in production.

## systemd units of the layer

| Unit | Type | Images | Role | Capabilities kept |
| --- | --- | --- | --- | --- |
| `nftables.service` | oneshot | all | load the firewall before the network services | `CAP_NET_ADMIN` |
| `sharebox-setup.service` | oneshot | all | merge build defaults and `/data/config/sharebox.conf`, write `/run/sharebox/*` | none (no network) |
| `hostapd.service` | simple | all | access point | `CAP_NET_ADMIN`, `CAP_NET_RAW` |
| `dnsmasq.service` | simple | all | DHCP and wildcard DNS | `CAP_NET_BIND_SERVICE`, `CAP_NET_RAW`, `CAP_NET_ADMIN`, `CAP_SETUID`, `CAP_SETGID`, `CAP_DAC_OVERRIDE` (dropped after start, runs as `dnsmasq`) |
| `sharebox-usb-scan.service` | oneshot | all | link the newest USB stick, import `sharebox/sharebox.conf`, run USB hooks | none (no network) |
| `media.mount` | mount | all | tmpfs on `/media` for USB mount points | - |
| `sharebox-grow-data.service` | oneshot | all | grow the data partition at first boot | `CAP_SYS_ADMIN`, `CAP_SYS_RESOURCE` |
| `sharebox-healthcheck.service` | oneshot | all, with updates | commit the booted slot or roll back | none |
| `sharebox-update-install.path` / `.service` | path / oneshot | all, with updates | install a bundle queued from `/status` | none (talks to `rauc.service` over D-Bus) |
| `rauc.service` | D-Bus | all, with updates | RAUC daemon (meta-rauc) | upstream unit |
| `lighttpd.service` | simple | base, modular, library, full | HTTP front end | `CAP_NET_BIND_SERVICE` |
| `luffy.service` | simple | classic | luffy on port 80 | `CAP_NET_BIND_SERVICE` |
| `shareboxx.service` | simple | shareboxx | ShareBoxx on port 80 | `CAP_NET_BIND_SERVICE` |
| `dufs.service` | simple | modular, full | writable file share | none |
| `dufs-ro.service` | simple | library, full | read-only file share | none |
| `ergo.service` | notify | modular, full | IRC server | none |
| `kiwix-serve.service` | simple | library, full | ZIM content server (`MemoryMax` per machine) | none |
| `kiwix-library-update.service` | oneshot | library, full | rebuild `/data/zim/library.xml` | none (no network) |

Every network service unit `Requires=` and comes `After=`
`sharebox-setup.service` and reads `/run/sharebox/env`; restarting
`sharebox-setup.service` applies a new configuration. The hardening
directives common to all units are listed in
[`ARCHITECTURE.md`](ARCHITECTURE.md), "systemd unit hardening".

Units from oe-core and meta-rauc that are not specific to ShareBox
(systemd-journald, systemd-udevd, systemd-networkd, systemd-logind,
systemd-tmpfiles, dbus) keep their upstream configuration. journald is
volatile.
