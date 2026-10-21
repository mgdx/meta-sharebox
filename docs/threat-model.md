# Threat model

This document describes who may attack a ShareBox, what they may target,
what the layer does about it, and what risks remain. It covers the
production distro (`sharebox`) built with the default settings. The
development distro (`sharebox-dev`) is not meant to be deployed. Listening
sockets and units per image: [`ports-and-services.md`](ports-and-services.md).

## System summary

A ShareBox is a Raspberry Pi running an open Wi-Fi access point (no WPA, no
OWE) on `wlan0`, address `192.168.77.1/24`, name `sharebox.lan`. dnsmasq
gives addresses and answers every DNS name with the box address. An HTTP
front end on port 80 (lighttpd, luffy or ShareBoxx depending on the image)
serves the home page, the captive portal answers, a `/status` page and the
sharing engine. The box has no route to the Internet and never forwards
packets. The root filesystem is a read-only erofs image; persistent state is
on the `/data` partition. Updates are signed RAUC bundles installed from a
USB stick after a confirmation on `/status`.

## Attackers

| Attacker | Capabilities | In scope |
| --- | --- | --- |
| **A1. Client in radio range** | associates with the open network (no credentials needed), gets a DHCP lease, sends arbitrary traffic to the box, sniffs all radio traffic, uses any HTTP client, uploads files, posts in the chat, presses buttons on `/status` | yes, the main attacker |
| A2. Radio attacker not associated | jamming, deauthentication frames, rogue access point with the same SSID (evil twin) | partly: no mitigation is possible on an open network, see residual risks |
| A3. Someone who brings a USB stick | plugs a stick with arbitrary content (files, `sharebox/sharebox.conf`, `.raucb` bundles, crafted filesystems) | yes |
| A4. Physical attacker with time | removes the SD card, connects to the UART header, replaces the box | no (out of scope, listed for completeness) |
| A5. Supply chain | compromised upstream source, compromised build host or signing key | partly: pinned sources, checksums, SBOM; key handling is the integrator's job |

## Assets

| Asset | Why it matters |
| --- | --- |
| Integrity of the box software (rootfs, kernel, boot chain) | a compromised box can serve malware or phishing pages to every client |
| Availability of the access point and the services | the box is the only shared resource of its users |
| Shared files (`/data/share`) and USB content | the purpose of the box; should not be altered or deleted by visitors |
| Clients (phones, laptops) | must not be reachable from other clients through the box |
| Box configuration (`/data/config`) | SSID, country, upload limit; changing it may break the box or its legal compliance |
| RAUC signing key (off the box) | whoever holds it can install any software on every box that trusts it |
| Users' privacy | the box must not log more than needed (message contents, client addresses) |

## Mitigations implemented

### Network exposure (A1)

- **Firewall** (`recipes-connectivity/nftables/files/sharebox.nft`, loaded
  before any network service): `input` and `forward` policy `drop`. From
  `wlan0` only udp 53 and 67 and tcp 53 and 80 are accepted; new TCP
  connections are limited to 50 per second; tcp 443 is answered with a TCP
  reset so that browsers fail fast instead of timing out; ping is rate
  limited. Port 80 and 53 traffic for any destination address is
  redirected to the box.
- **No routing**: `forward` drops everything, `net.ipv4.ip_forward = 0`,
  IPv6 forwarding off, redirects and source routing refused, router
  advertisements ignored (`90-sharebox.conf` sysctl file).
- **Client isolation**: hostapd runs with `ap_isolate=1`; clients cannot
  talk to each other through the access point.
- **Localhost-only engines**: every service behind lighttpd listens on
  `127.0.0.1` only (dufs 5000/5001, Ergo 6667/8097, kiwix-serve 8081), and
  its unit adds `IPAddressDeny=any` + `IPAddressAllow=localhost`. Only the
  front end (port 80) and dnsmasq (53, 67) face `wlan0`.
- **No remote shell**: the production distro has no SSH server, no serial
  console and no login on the UART; root has no usable password.
- **Wildcard DNS with TTL 0** keeps clients on the box; dnsmasq has
  `no-resolv`, so it never queries anything upstream.

### Services (A1)

- **systemd sandboxing** of every unit of the layer
  (`docs/ARCHITECTURE.md`, "systemd unit hardening"): dedicated
  unprivileged users (`www`, `sharebox`, `ergo`, `kiwix`, `dnsmasq`),
  capability bounding sets limited to what is needed (`CAP_NET_BIND_SERVICE`
  for the port 80 servers, `CAP_NET_ADMIN`/`CAP_NET_RAW` for hostapd and
  dnsmasq, none for the engines), `NoNewPrivileges`, `ProtectSystem=strict`
  with explicit writable paths, `PrivateTmp`, `PrivateDevices`,
  `MemoryDenyWriteExecute`, `SystemCallFilter=@system-service`,
  `RestrictAddressFamilies`, `RestrictNamespaces`, `UMask=0077`. The target
  is a `systemd-analyze security` score below 3.0 per unit (to be measured
  on hardware).
- **Uploads are data, never code**: anonymous writes are limited to
  `/data/share/upload`; no CGI runs on `/data`; dufs has no delete, move or
  overwrite right; lighttpd answers `/files/` and `/upload/` with
  `X-Content-Type-Options: nosniff`, and adds `Content-Disposition:
  attachment` and `Content-Security-Policy: sandbox` for active types
  (HTML, SVG, JavaScript, executables, scripts...). Global headers set
  frame and referrer policies.
- **Upload size limit**: `server.max-request-size` (lighttpd), luffy and
  ShareBoxx limits, all from `upload_max` / `SHAREBOX_UPLOAD_MAX`; `0`
  disables uploads.
- **Path traversal fix in ShareBoxx**: the layer patch rejects absolute
  upload paths and `..` (`docs/deviations.md`, "Shareboxx").
- **Chat**: Ergo without accounts, at most 4 connections per client
  address (the real address is taken from the proxy header, accepted only
  from localhost), flood limits, history expiring after one week, no
  logging of message contents or client addresses.
- **kiwix-serve memory limit** (`MemoryMax=`, per machine) so that a heavy
  search cannot exhaust the RAM of the box.
- **Configuration parsing**: `sharebox.conf` is parsed with a fixed list of
  keys, never sourced; invalid values are ignored with a warning; values
  written to generated files are escaped.
- **`/status` client counter** reads the ARP table instead of the hostapd
  control socket, so the web server cannot reconfigure the access point.

### Integrity (A1, A3)

- **Read-only root**: erofs, mounted read-only; nothing can be written to
  `/usr` at run time. `/etc` and `/var` are overlays on `/data`, and the
  account databases are reset from the image after each update.
- **Signed updates**: RAUC verity bundles signed with X.509; the keyring
  (CA certificate) in `/usr/lib/rauc/` comes from the read-only image. A
  bundle is checked when the stick is plugged (`rauc info`) and again at
  installation (signature, compatible string, dm-verity).
- **Install only after confirmation**: a bundle on a stick is never
  installed automatically; the `/status` page shows it and waits for a
  POST on the "Install" button. The web server (user `www`) can only queue
  a request naming the already verified candidate; a separate root unit
  without capabilities performs the installation.
- **A/B with rollback**: a new slot is only committed by
  `sharebox-healthcheck` once the access point, DHCP/DNS and port 80 are up;
  otherwise the box falls back to the previous slot.
- **USB sticks** are mounted read-only with `nosuid,nodev,noexec`; the scan
  service and its hooks run as root without any capability, without
  network and without device access.
- **No secrets in the image**: no password, no private key, no per-device
  credential. The RAUC CA certificate is the only cryptographic material.
- **U-Boot**: `CONFIG_BOOTDELAY=-2` in production, so the boot cannot be
  interrupted from the UART or a USB keyboard.

### Build and supply chain (A5)

- Compiler hardening from oe-core `security_flags.inc` (stack protector,
  PIE, `_FORTIFY_SOURCE`, full RELRO); QA errors for `buildpaths`,
  `dev-so`, `ldflags`, `patch-fuzz`.
- Kernel hardening fragment: [`kernel-hardening.md`](kernel-hardening.md).
- Pinned sources: layer commits in `kas/common.yml`, `SRCREV` on tags,
  generated crate and Go module lists with checksums, SHA-256 of every
  downloaded tarball and of the ShareBoxx web assets.
- SPDX 3.0 SBOM and `sbom-cve-check` for every image
  ([`cra.md`](cra.md)).
- The image build fails if `python3*`, `perl*`, `php*` or `nodejs*`
  packages end up in the image.

## Residual risks

| Risk | Why it remains | Mitigation or advice |
| --- | --- | --- |
| **Traffic sniffing and tampering on the open network** | there is no Wi-Fi encryption and HTTP is plain text: anyone in range can read what others download, upload or write in the chat, and can inject or alter traffic of other clients at the radio level | by design (no password to share, no certificate an offline box could get trusted). Tell users that everything on the box is public. |
| **Evil twin** | another device can broadcast the same SSID and serve its own pages | none possible on an open network |
| **Deauthentication and jamming** | 802.11w (PMF) needs WPA; an open network cannot protect management frames | none; the box recovers when the attack stops |
| **Anonymous uploads** | anybody can upload illegal, malicious or simply large content; there is no moderation and no per-client quota | upload limit per file, `upload_max=0` to disable, `library` image has no upload at all; the operator should review `/data/share/upload` |
| **Disk filling** | uploads go to `/data`, which also holds the `/etc` and `/var` overlays and the chat history; a full partition can block configuration changes and logs on disk | to do: a quota or a separate upload partition |
| **Status page "Install" button reachable by any client** | the network is open, so any client can confirm the installation of a bundle that is on a plugged stick | only bundles signed by the build's key are accepted; the button cannot install anything else. Do not leave update sticks plugged in unattended. |
| **Development RAUC keys** | the layer ships public development keys used by default; a box built with them accepts bundles signed by anyone | the build warns for the `sharebox` distro; production builds must set `RAUC_KEY_FILE`, `RAUC_CERT_FILE`, `RAUC_KEYRING_FILE` (`files/rauc-keys/README.md`) |
| **Configuration from a USB stick** | anyone who can plug a stick can change the SSID, country, channel or upload limit with `sharebox/sharebox.conf` | physical access is needed; values are validated; keep the box out of reach if this matters |
| **Cross-site scripting through the engines** | luffy and ShareBoxx serve port 80 themselves, so the lighttpd headers (`nosniff`, `attachment`, `CSP: sandbox`) do not apply in the `classic` and `shareboxx` images | review of both engines pending; prefer `modular` where uploads are open |
| **Chat impersonation and spam** | no accounts: any nickname can be used | flood limits only |
| **UART enabled when U-Boot is used** | meta-raspberrypi requires `enable_uart=1` with U-Boot; U-Boot still prints on it | no console or login is attached in production, autoboot cannot be interrupted; physical access is out of scope (`docs/deviations.md`) |
| **Physical access** | the SD card is not encrypted and the boot chain is not verified (no secure boot, no dm-verity on the rootfs slots yet: `SHAREBOX_VERITY` is not implemented) | out of scope for v1; meta-raspberrypi secure boot is a later option |
| **Kernel modules not signed** | `module.sig_enforce` is not configured yet | the rootfs is read-only and no service can load modules (`ProtectKernelModules`), see `kernel-hardening.md` |
| **Unmeasured hardening** | `systemd-analyze security` scores, `kernel-hardening-checker` results and `lynis` have not been run on hardware yet | acceptance tests (`scripts/test-target.sh`, CI) |
| **Vulnerable components between releases** | a box is updated only when someone brings a stick | 14-day target for critical fixes (`SECURITY.md`); boxes built with `SHAREBOX_UPDATES = "0"` need a reflash |
