# Security policy

ShareBox is a device that sits on an open Wi-Fi network: anybody in radio
range can talk to it. Security reports are welcome and handled with
priority. The threat model is in [`docs/threat-model.md`](docs/threat-model.md).

## Reporting a vulnerability

**Do not open a public issue for a vulnerability.**

Report it privately through GitHub security advisories:

1. Go to <https://github.com/mgdx/meta-sharebox/security/advisories/new>
   (repository "Security" tab, "Report a vulnerability").
2. Describe the affected image(s), machine(s) and ShareBox version
   (`VERSION_ID` in `/etc/os-release`, also shown on `http://sharebox.lan/status`),
   how to reproduce, and the impact you expect.
3. Attach a proof of concept if you have one. Please do not test against
   boxes you do not own.

What happens next:

| Step | Target delay |
| --- | --- |
| Acknowledgement of the report | 5 working days |
| First assessment (accepted or not, severity) | 10 working days |
| Fix released for a critical vulnerability | 14 days after confirmation |
| Fix released for other vulnerabilities | next scheduled release (at least quarterly) |
| Public advisory (GitHub advisory, CVE when applicable) | when the fix is released, crediting the reporter unless asked otherwise |

If the vulnerability is in an upstream component (hostapd, dnsmasq,
lighttpd, the Linux kernel, an engine such as dufs, Ergo, luffy, ShareBoxx,
kiwix-serve...), we also report it upstream, or coordinate with you if you
already did. Vulnerabilities of Yocto/OpenEmbedded recipes that ShareBox
uses unchanged are fixed by updating to the corresponding Wrynose stable
release.

## Supported versions

| Version | Yocto release | Supported until |
| --- | --- | --- |
| 0.x (prototype, unreleased) | 6.0 Wrynose | best effort, no released version yet |
| 1.x (first release) | 6.0 Wrynose (LTS) | April 2030, end of Wrynose LTS support |

Only the latest minor version of a supported series receives fixes. Each
release is published for every image and every supported machine, as SD
card images and as signed RAUC update bundles (when updates are enabled).

The support period follows the Yocto Project LTS: once Wrynose is no longer
maintained upstream, ShareBox images built on it are no longer supported.
Moving to the next Yocto LTS requires a new major version of the layer.

## Vulnerability handling

- **Monitoring**: every image build runs `sbom-cve-check` against the SPDX
  SBOM of the image, with up-to-date CVE databases (CVEProject cvelistV5
  and the NVD JSON feeds). Results are reviewed for each release.
- **Critical CVEs** affecting hostapd, dnsmasq, lighttpd, the Linux kernel
  or a sharing engine shipped in an image are fixed in a corrective
  release **within 14 days**. The same applies to any other component when
  it is reachable from the Wi-Fi network.
- **Other CVEs** are fixed in the next scheduled release (at least one per
  quarter, following the Wrynose stable updates).
- A CVE that does not apply (vulnerable code not built, not reachable) is
  documented with `CVE_STATUS` in the recipe, so that it appears as such in
  the VEX data of the SBOM.
- **Delivery**: fixes are delivered as signed RAUC bundles to install from
  a USB stick (see [`docs/updates.md`](docs/updates.md)). Boxes built with
  `SHAREBOX_UPDATES = "0"` can only be updated by reflashing the card.

## Artefacts published with each image

For every image and machine, the build produces in
`tmp/deploy/images/<machine>/`:

| Artefact | File |
| --- | --- |
| SBOM, SPDX 3.0 JSON (sources embedded when `SPDX_INCLUDE_SOURCES = "1"`, VEX included) | `sharebox-image-<engine>-<machine>.rootfs.spdx.json` |
| CVE scan, SPDX 3.0 with vulnerability data | `<image>.rootfs.sbom-cve-check.spdx.json` |
| CVE scan, cve-check compatible JSON | `<image>.rootfs.sbom-cve-check.yocto.json` |
| CVE scan, human-readable summary | `<image>.rootfs.cve.txt` |
| Installed package list | `<image>.rootfs.manifest` |
| SD card image and block map | `<image>.rootfs.wic.gz`, `<image>.rootfs.wic.bmap` |
| Signed update bundle | `sharebox-bundle-<engine>-<machine>.raucb` |

The `build` GitHub workflow (`.github/workflows/build.yml`) collects these
files as build artefacts. More on the CRA documentation:
[`docs/cra.md`](docs/cra.md).
