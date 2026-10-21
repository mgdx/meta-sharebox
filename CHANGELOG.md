# Changelog

All notable changes to meta-sharebox. Versions follow
`MAJOR.MINOR.PATCH` (`DISTRO_VERSION`, shown in `/etc/os-release` and on
the `/status` page).

## 0.1.0 (unreleased)

First prototype for Yocto 6.0 Wrynose. Builds, not yet validated on
hardware.

### Distro and base system

- `sharebox` (production) and `sharebox-dev` (dropbear with public keys
  only on non-Wi-Fi interfaces, serial console) distros: systemd, glibc,
  no Python, Perl, PHP or Node.js on target (checked at image build time).
- Raspberry Pi support through meta-raspberrypi: Pi Zero W, Zero 2 W, 3, 4,
  5; kas files for each machine with pinned layer commits.
- Open access point (hostapd, `ap_isolate=1`), DHCP and wildcard DNS with
  TTL 0 (dnsmasq), static `192.168.77.1/24`, `sharebox.lan`.
- Captive portal in `popup` or `silent` mode, answering the probes of
  Android, Chrome, Apple, Windows, Firefox, NetworkManager, KDE, Ubuntu and
  Fedora.
- Runtime configuration: `sharebox-setup` merges the build defaults
  (`SHAREBOX_*`) with `/data/config/sharebox.conf` (SSID, language,
  country, channel, band, upload limit, captive mode), also importable
  from a USB stick; world regulatory domain when no country is set.
- Home, "How it works" and `/status` pages in 41 languages
  (AI translations awaiting review, see `TRANSLATIONS.md`), with
  `Accept-Language` negotiation and localized SSIDs.
- USB sticks mounted read-only (ext4, exFAT, NTFS, FAT), newest stick
  linked into the share, hooks for engines.

### Images and engines

- `sharebox-image-base`: base system and home page only.
- `sharebox-image-classic`: luffy (PirateBox compatible), uploads on the
  main port.
- `sharebox-image-modular`: lighttpd, dufs (files, WebDAV, resumable
  anonymous upload), Ergo IRC server with SQLite history (no CGO), gamja
  web client.
- `sharebox-image-shareboxx`: ShareBoxx 1.1.4 server built from source with
  the upstream web assets; path traversal fix in the upload handler.
- `sharebox-image-library`: kiwix-serve 3.8.2 (libkiwix 14.2.1, libzim 9.8.2,
  xapian-core 1.4.32), read-only dufs.
- `sharebox-image-full`: modular and library together (Pi 4, Pi 5).
- No forum: Sriracha is not packaged (see `docs/deviations.md`).

### Storage and updates

- Read-only erofs (lz4hc) root filesystem, `/etc` and `/var` overlays on
  the persistent ext4 `/data` partition, grown at first boot.
- A/B updates with RAUC 1.15 and U-Boot: signed verity bundles
  (`sharebox-bundle-<engine>`), installed from a USB stick only after a
  confirmation on `/status`, health check and automatic rollback.
- `SHAREBOX_UPDATES = "0"` builds single-slot, reflash-only images.

### Security and compliance

- nftables firewall (only udp 53/67 and tcp 53/80 from Wi-Fi, 443 reset,
  no forwarding), sysctl hardening, kernel hardening fragment.
- Every unit of the layer sandboxed with systemd (dedicated users, minimal
  capabilities, localhost-only engines).
- SPDX 3.0 SBOM and `sbom-cve-check` for every image.
- Documentation: `README.md`, `SECURITY.md`, `docs/threat-model.md`,
  `docs/ports-and-services.md`, `docs/kernel-hardening.md`, `docs/cra.md`.

### Tooling

- `scripts/build-all.sh`, `scripts/flash.sh`, `scripts/check-image-size.sh`,
  `scripts/check-forbidden-packages.sh`, `scripts/test-target.sh` and host
  unit tests of the runtime scripts.
- GitHub Actions: shell and host tests, translation check, kas parse and
  `yocto-check-layer` (`ci.yml`); full builds with SBOM, CVE and kernel
  hardening reports on a self-hosted runner (`build.yml`).

### Known limitations

- Not validated on hardware: client limits, boot times, captive portal
  behaviour, power-cut resilience and updates still need the acceptance
  tests.
- Kernel module signing, dm-verity on the rootfs slots (`SHAREBOX_VERITY`)
  and the Pi 5 `tryboot` alternative are not implemented.
- The layer ships public development RAUC keys: production builds must use
  their own.
