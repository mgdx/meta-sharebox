# meta-sharebox

meta-sharebox is a Yocto layer that builds **ShareBox**, an offline
file-sharing Wi-Fi box for the Raspberry Pi. It continues the work of
PirateBox and LibraryBox. The box opens a Wi-Fi network with no password,
answers the captive portal probes of phones and laptops, and serves a local
home page. Depending on the image, that page offers files, anonymous
uploads, a chat or an offline encyclopedia. The box never connects to the
Internet.

- Yocto 6.0 **Wrynose** (LTS, supported until April 2030), `LAYERSERIES_COMPAT = "wrynose blacksail"`.
- BSP: [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi) only.
- Distro `sharebox` (production) and `sharebox-dev` (adds SSH and a serial console).
- systemd, glibc, read-only erofs root filesystem, persistent `/data`
  partition, nftables, signed A/B updates from a USB stick (RAUC).
- No Python, Perl, PHP or Node.js on the target.

> **Status: prototype.** The layer parses and the images build, but nothing
> has been validated on hardware yet: boot times, client limits, captive
> portal behaviour on real phones, power-cut resilience and updates still
> have to go through the acceptance tests (`scripts/test-target.sh`).

Last verified build (2026-10-21, `raspberrypi4-64`, pinned kas revisions):
all six images and the `sharebox-bundle-modular` RAUC bundle build without
QA errors. Read-only erofs rootfs sizes: base 71.7 MiB, classic 75.3 MiB,
modular 81.8 MiB, shareboxx 79.0 MiB, library 102.5 MiB, full 110.8 MiB,
all under the specification thresholds. No python3, perl, php or nodejs
package in any image. `sbom-cve-check` only reports upstream oe-core and
kernel CVEs.

## Images

Every image shares the same base system (access point, DHCP/DNS, captive
portal, firewall, USB sticks, updates). They differ only by their sharing
engine.

| Image | Engine | What users get | Port 80 served by | Machines (`COMPATIBLE_MACHINE`) |
| --- | --- | --- | --- | --- |
| `sharebox-image-base` | none | home page, "How it works", `/status` | lighttpd | all |
| `sharebox-image-classic` | [luffy](https://github.com/et0and/luffy) (Go) | PirateBox look: files, anonymous upload, shoutbox chat, forum | luffy | all, including the Pi Zero W |
| `sharebox-image-modular` | lighttpd + [dufs](https://github.com/sigoden/dufs) + [Ergo](https://github.com/ergochat/ergo) + [gamja](https://codeberg.org/emersion/gamja) | files with WebDAV, resumable anonymous upload, IRC chat in the browser | lighttpd | all (64-bit machines recommended) |
| `sharebox-image-shareboxx` | [ShareBoxx](https://github.com/dividebysandwich/shareboxx) (Rust) | files, large uploads, live chat (needs JavaScript and WebAssembly) | ShareBoxx | 64-bit only: Zero 2 W, Pi 3, Pi 4, Pi 5 |
| `sharebox-image-library` | lighttpd + [kiwix-serve](https://github.com/kiwix/kiwix-tools) + dufs (read-only) | offline Wikipedia and other ZIM files, read-only file share, no upload | lighttpd | all (Pi 3, 4, 5 recommended; Zero 2 W with small ZIM files only) |
| `sharebox-image-full` | modular + library | everything above (no forum) | lighttpd | Pi 4, Pi 5 and generic `raspberrypi-armv8` |

The specification also plans a forum (Sriracha) in `modular` and `full`;
it is not packaged. See [`docs/deviations.md`](docs/deviations.md).

## Supported machines

| kas file | `MACHINE` | Boards | Wi-Fi |
| --- | --- | --- | --- |
| `kas/rpi0-w.yml` | `raspberrypi0-wifi` | Pi Zero W (armv6, 32-bit, 512 MB) | 2.4 GHz |
| `kas/rpi0-2w-64.yml` | `raspberrypi0-2w-64` | Pi Zero 2 W (512 MB) | 2.4 GHz |
| `kas/rpi3-64.yml` | `raspberrypi3-64` | Pi 3 B, 3 B+, 3 A+ | 2.4 GHz; 5 GHz on 3 B+ and 3 A+ |
| `kas/rpi4-64.yml` | `raspberrypi4-64` | Pi 4 B, Pi 400, CM4 | 2.4 and 5 GHz |
| `kas/rpi5.yml` | `raspberrypi5` | Pi 5, Pi 500 | 2.4 and 5 GHz |

`raspberrypi4-64` is the reference build machine. Pi models without
on-board Wi-Fi (Pi 1, Pi 2, Zero without W) may build but are not targets.

**Radio limits.** The on-board Broadcom chip (brcmfmac driver) runs a single
access point on a single channel, with no client (station) interface at
the same time. Expect about **8 simultaneously associated clients**: that
figure comes from earlier measurements on Pi 3 B+ and Pi 4 and must be
measured again with the Wrynose 6.18 kernel, in particular on Pi 5 and
Zero 2 W. hostapd itself accepts up to 32 stations. The measured value per
machine will be added here.

## Quick start

### Host requirements

- A Linux host supported by Yocto Wrynose, with the
  [Yocto build host packages](https://docs.yoctoproject.org/ref-manual/system-requirements.html)
  installed.
- About **60 GB** of free disk space for one machine and a few images
  (downloads, shared state and work directories; `rm_work` is enabled).
  The CVE databases used by `sbom-cve-check` add several GB to the
  download directory.
- 32 GB of RAM is comfortable. With **16 GB**, turn off source embedding in
  the SBOM and lower the parallelism, for example in a personal kas
  overlay `kas/local.yml` (ignored by git):

  ```yaml
  header:
    version: 14
  local_conf_header:
    local: |
      SPDX_INCLUDE_SOURCES = "0"
      BB_NUMBER_THREADS = "4"
      PARALLEL_MAKE = "-j 4"
      # optional on developer builds: skip the CVE scan and its databases
      SHAREBOX_CVE_CHECK = "0"
  ```

  and build with `kas build kas/rpi4-64.yml:kas/local.yml`.

### Build with kas

```sh
pipx install kas
git clone https://github.com/mgdx/meta-sharebox.git
cd meta-sharebox

# default image (sharebox-image-base) for the Pi 4
kas build kas/rpi4-64.yml

# another image
kas build kas/rpi4-64.yml --target sharebox-image-modular

# development distro (SSH on Ethernet / USB gadget, serial console)
kas build kas/rpi4-64.yml:kas/dev.yml --target sharebox-image-modular

# a signed update bundle for the same image
kas build kas/rpi4-64.yml --target sharebox-bundle-modular
```

kas clones the dependency layers next to the checkout (or into
`KAS_WORK_DIR`) and builds in `build/`. Results are in
`build/tmp/deploy/images/<machine>/`:

| File | Content |
| --- | --- |
| `sharebox-image-<engine>-<machine>.rootfs.wic.gz` and `.wic.bmap` | SD card image |
| `sharebox-image-<engine>-<machine>.rootfs.erofs` | root filesystem (also the update payload) |
| `sharebox-image-<engine>-<machine>.rootfs.manifest` | installed packages |
| `sharebox-image-<engine>-<machine>.rootfs.spdx.json` | SPDX 3.0 SBOM |
| `sharebox-image-<engine>-<machine>.rootfs.sbom-cve-check.*`, `.cve.txt` | CVE scan results |
| `sharebox-bundle-<engine>-<machine>.raucb` | signed RAUC update bundle |

`scripts/build-all.sh` builds every image for every machine it is
compatible with.

### Flash

```sh
sudo apt install bmap-tools        # or: pipx install bmaptool
scripts/flash.sh build/tmp/deploy/images/raspberrypi4-64/sharebox-image-modular-raspberrypi4-64.rootfs.wic.gz /dev/sdX
```

`scripts/flash.sh` wraps `bmaptool copy`. It refuses a disk that is not
removable or that has a mounted partition, and asks for confirmation. By
hand: `bmaptool copy <image>.wic.gz /dev/sdX`.

### First boot

1. Insert the card and power the Pi. At first boot the data partition is
   grown to fill the card.
2. Join the open Wi-Fi network **`ShareBox - Share Freely`** (the name
   depends on the language, see below).
3. Phones and laptops show a "Sign in to network" notification (popup
   mode) that opens the home page. Otherwise browse to
   `http://sharebox.lan/` or `http://192.168.77.1/`.
4. `http://sharebox.lan/status` shows the version, connected clients, free
   space, configuration warnings and, when a USB stick holds a valid update,
   the "Install" button.

The production distro has no shell access at all: no SSH, no login on the
serial port. Use the `sharebox-dev` distro (`kas/dev.yml`) for debugging:
dropbear accepts public keys only and only on interfaces other than
`wlan0`.

## Layer dependencies

| Layer | Repository | Branch |
| --- | --- | --- |
| bitbake | https://git.openembedded.org/bitbake | `2.18` |
| openembedded-core (`meta`) | https://git.openembedded.org/openembedded-core | `wrynose` |
| meta-oe, meta-networking, meta-filesystems | https://git.openembedded.org/meta-openembedded | `wrynose` |
| meta-multimedia (optional, only for `SHAREBOX_DLNA = "1"`) | https://git.openembedded.org/meta-openembedded | `wrynose` |
| meta-raspberrypi | https://git.yoctoproject.org/meta-raspberrypi | `wrynose` |
| meta-rauc | https://github.com/rauc/meta-rauc | `wrynose` |

The exact commits are pinned in [`kas/common.yml`](kas/common.yml) (which
also adds meta-python to the layer list). meta-rauc-raspberrypi is not a
dependency: the parts that ShareBox needs are reimplemented in this layer.

## Customization

There are two levels: **build time** variables in `local.conf` or a kas
overlay, baked into the image as defaults, and **run time** settings in
`/data/config/sharebox.conf` on the box, which override them.

### Wi-Fi regulatory domain

ShareBox does not assume a country. **Without a country, the kernel stays
in the world regulatory domain (`00`)**: 2.4 GHz only, channels 1 to 11, at
reduced power, no transmission at 5 GHz. That is legal everywhere.

Setting a country (`country=FR`, `SHAREBOX_COUNTRY = "FR"`) writes
`country_code` to hostapd and unlocks the rules of that country:
channels 1 to 13 at 2.4 GHz and, on boards with a 5 GHz radio (Pi 3 B+,
3 A+, 4, 5), the 5 GHz band (`band=5`) on channels 36, 40, 44, 48 or 149 to
165 with 40 MHz channels (HT40). 80 MHz (VHT80) is never used. The country
of the regulatory database still decides what is allowed: a channel that
the country forbids makes hostapd fail.

The rules applied by `sharebox-setup` at boot:

- `band=5` without a country, or on a board without 5 GHz: stays on 2.4 GHz
  with a warning.
- A channel outside the allowed range: channel 6 (2.4 GHz) or 36 (5 GHz)
  with a warning.
- Warnings are shown on `/status`.

**The person who deploys the box is responsible for setting the country
where it operates** and for complying with the local radio rules. The
layer only guarantees that the default (no country) is legal everywhere.

### Run time settings: `/data/config/sharebox.conf`

A plain `key=value` file, one setting per line. Blank lines and lines
starting with `#` or `;` are ignored, values may be quoted. The file is
parsed, never executed: unknown keys and invalid values are ignored with a
warning shown on `/status`. A missing key keeps the build time default.

| Key | Values | Default | Effect |
| --- | --- | --- | --- |
| `ssid` | 1 to 32 bytes of UTF-8, no control characters | generated from the language | Wi-Fi network name |
| `lang` | a shipped language code (`en`, `fr`, `pt-BR` → `pt`, ...) | from the country, else `en` | default page language and generated SSID |
| `country` | ISO 3166-1 alpha-2 code (`FR`, `US`), empty or `00` for none | none (world domain) | regulatory domain |
| `channel` | 1 to 11 (no country), 1 to 13 (country), 36 to 48 or 149 to 165 (5 GHz) | `6` | Wi-Fi channel |
| `band` | `2.4` or `5` | `2.4` | 5 GHz needs a country and a 5 GHz board |
| `upload_max` | size with an optional `K`, `M`, `G` suffix; `0` disables uploads | `2G` | largest accepted upload |
| `captive_mode` | `popup` or `silent` | `popup` | captive portal behaviour (see below) |

Example for a box in France, on 5 GHz, with a custom name and 500 MB
uploads:

```ini
# /data/config/sharebox.conf
ssid=Médiathèque - partage
lang=fr
country=FR
band=5
channel=36
upload_max=500M
captive_mode=popup
```

A minimal one, read-only box in English with the generated SSID:

```ini
lang=en
upload_max=0
```

How to change it:

- **USB stick**: put the file at `sharebox/sharebox.conf` on the stick
  (vfat, exFAT, NTFS or ext4) and plug it in. The box copies it to
  `/data/config/sharebox.conf` (replacing the previous one) and restarts
  the access point and the web services. The setting stays after the stick
  is removed.
- **SD card**: edit `config/sharebox.conf` on the data partition (the last
  ext4 partition of the card) from a Linux PC.
- **Dev image**: edit the file over SSH, then
  `systemctl restart sharebox-setup`.

The host name and the address of the box (`sharebox.lan`,
`192.168.77.1/24`) and the update mechanism are build time only.

### Language and network name

Pages and SSIDs ship in 41 languages (status of each translation:
[`TRANSLATIONS.md`](TRANSLATIONS.md)). The box picks:

- **Default language**: `lang=`, else `SHAREBOX_LANG`, else the single
  official language of the country when it is shipped (`country=PT` gives
  `pt`; a country with several official languages gives English), else
  English. Browsers still get the page in their own language when it is
  shipped (`Accept-Language`); the default is the fallback.
- **SSID**: `ssid=`, else `SHAREBOX_SSID`, else the generated name
  `ShareBox - <slogan>` of the default language, else the English one
  (`ShareBox - Share Freely`) when the translated name does not fit in
  32 bytes.

Details: [`docs/i18n.md`](docs/i18n.md).

### Upload size

`upload_max` (run time) or `SHAREBOX_UPLOAD_MAX` (build time) sets the
largest accepted upload, in bytes with an optional `K`/`M`/`G` suffix
(powers of 1024). `0` disables anonymous uploads: the engines refuse them.
The home page hides its upload card only when the limit is `0` at build
time (`SHAREBOX_UPLOAD_MAX = "0"`); with `upload_max=0` at run time the card
stays and uploads are refused. The limit is enforced by lighttpd
(`server.max-request-size`) in front of dufs, and passed to luffy and
ShareBoxx. The `library` image has no upload at all.

### Captive portal mode

- **`popup`** (default): every HTTP request for a foreign host is
  redirected to the home page. Phones and laptops see a captive network
  and open the "Sign in" window on the home page.
- **`silent`** (PirateBox behaviour): the known probes (Android/Chrome,
  Apple, Windows, Firefox, NetworkManager, KDE, Ubuntu, Fedora) get the
  answer of a network with Internet access, so no window opens and phones
  keep the Wi-Fi; users have to browse to `http://sharebox.lan/`.

The `classic` image (luffy) always behaves like `silent`. Which mode keeps
Android phones connected best without Internet is still to be measured.

### Updates on or off

`SHAREBOX_UPDATES = "1"` (default) builds A/B images: two root filesystem
slots, U-Boot, and signed RAUC bundles installed from a USB stick after a
confirmation on `/status` ([`docs/updates.md`](docs/updates.md)). **Production
builds must use their own signing keys** ([`files/rauc-keys/README.md`](files/rauc-keys/README.md)):
the development keys in the layer are public.

`SHAREBOX_UPDATES = "0"` builds a single-slot image without RAUC and
without U-Boot. **The only way to update such a box is to reflash the
card.** There is no run time equivalent.

### Build time variables

Set them in a kas overlay (`local_conf_header`) or `local.conf`. Run time
keys of `sharebox.conf` override the first group.

| Variable | Default | Meaning |
| --- | --- | --- |
| `SHAREBOX_SSID` | empty (generated) | default SSID (`ssid=`) |
| `SHAREBOX_LANG` | empty (from country, else `en`) | default language (`lang=`) |
| `SHAREBOX_COUNTRY` | empty (world domain) | regulatory domain (`country=`) |
| `SHAREBOX_CHANNEL` | `6` | Wi-Fi channel (`channel=`) |
| `SHAREBOX_5GHZ` | `0` | `1` selects the 5 GHz band (`band=5`) |
| `SHAREBOX_UPLOAD_MAX` | `2G` | upload limit (`upload_max=`) |
| `SHAREBOX_CAPTIVE_MODE` | `popup` | `popup` or `silent` (`captive_mode=`) |
| `SHAREBOX_HOSTNAME` | `sharebox.lan` | DNS name of the box (build time only) |
| `SHAREBOX_IPV4` | `192.168.77.1/24` | address of `wlan0` (build time only) |
| `SHAREBOX_UPDATES` | `1` | A/B updates with RAUC, `0` for reflash-only images |
| `SHAREBOX_DEV` | `0` | set to `1` by the `sharebox-dev` distro |
| `SHAREBOX_CVE_CHECK` | `1` | `0` skips `sbom-cve-check` (developer builds) |
| `SHAREBOX_FORBIDDEN_PACKAGES` | `python3 perl php nodejs` | package prefixes that fail the image build |
| `SHAREBOX_DATA_FS` | `ext4` | data partition filesystem (`ext4`, `ext3`, `ext2`) |
| `SHAREBOX_DISK`, `SHAREBOX_UBOOT_DISK` | `mmcblk0`, `mmc 0` | boot disk (Linux and U-Boot names) |
| `SHAREBOX_BOOT_SIZE`, `SHAREBOX_ROOTFS_SIZE`, `SHAREBOX_DATA_SIZE` | `128M`, `512M`, `256M` | partition sizes (data grows at first boot) |
| `SHAREBOX_EROFS_OPTS` | `-zlz4hc` | `mkfs.erofs` options |
| `SHAREBOX_IMAGE_FSTYPES` | `erofs wic.gz wic.bmap` | image types |
| `SHAREBOX_RAUC_COMPATIBLE` | `sharebox-${MACHINE}` | RAUC compatible string |
| `SHAREBOX_DLNA` | `0` | `sharebox-image-full` only: add minidlna (needs meta-multimedia; firewall not opened yet) |
| `SHAREBOX_VERITY` | `0` | reserved for dm-verity on the rootfs slots; **not implemented yet** |
| `KIWIX_SERVE_MEMORY_MAX` | `512M` (256M Zero 2 W, 384M Pi 3, 1G Pi 5) | memory limit of kiwix-serve |
| `RAUC_KEY_FILE`, `RAUC_CERT_FILE`, `RAUC_KEYRING_FILE` | development keys | bundle signing, see `files/rauc-keys/README.md` |

Example kas overlay for a French deployment without updates:

```yaml
header:
  version: 14
local_conf_header:
  site: |
    SHAREBOX_COUNTRY = "FR"
    SHAREBOX_LANG = "fr"
    SHAREBOX_UPLOAD_MAX = "1G"
    SHAREBOX_UPDATES = "0"
```

## Documentation

| Document | Content |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | layer layout and internal conventions |
| [`docs/deviations.md`](docs/deviations.md) | where and why the layer differs from the specification |
| [`docs/updates.md`](docs/updates.md) | storage layout, A/B updates, USB update procedure |
| [`docs/i18n.md`](docs/i18n.md), [`TRANSLATIONS.md`](TRANSLATIONS.md) | languages, SSIDs, translation status |
| [`docs/threat-model.md`](docs/threat-model.md) | attacker model, assets, mitigations, residual risks |
| [`docs/ports-and-services.md`](docs/ports-and-services.md) | listening sockets, users and units per image |
| [`docs/kernel-hardening.md`](docs/kernel-hardening.md) | kernel configuration hardening and deviations |
| [`docs/cra.md`](docs/cra.md) | Cyber Resilience Act documentation index |
| [`SECURITY.md`](SECURITY.md) | reporting vulnerabilities, support period |
| [`CHANGELOG.md`](CHANGELOG.md) | release notes |

## Scripts

| Script | Use |
| --- | --- |
| `scripts/build-all.sh` | build every compatible machine × image pair with kas |
| `scripts/flash.sh` | write an image to an SD card with bmaptool, with safety checks |
| `scripts/check-image-size.sh` | compare rootfs sizes with the footprint targets |
| `scripts/check-forbidden-packages.sh` | look for interpreters in image manifests |
| `scripts/test-target.sh` | acceptance checks from a PC connected to the box Wi-Fi |
| `scripts/test-*.sh`, `scripts/check-i18n.sh` | host unit tests of the runtime scripts and translations |
| `scripts/gen-i18n-pages.sh` | regenerate the translated pages |
| `scripts/rauc-gen-keys.sh` | create a RAUC signing key set |

## License

The layer itself (recipes, classes, configuration, scripts, pages) is
released under the [MIT License](LICENSE). The software it builds keeps its
own licence: for example luffy and kiwix-tools are GPL-3.0, ShareBoxx and
libzim GPL-2.0, gamja AGPL-3.0, dufs MIT or Apache-2.0, Ergo MIT. Each recipe
declares its `LICENSE`, and the SPDX SBOM of every image lists them.
