# Cyber Resilience Act documentation

This page indexes the documentation that the EU Cyber Resilience Act (CRA,
Regulation (EU) 2024/2847) expects for a product with digital elements, and
where each part lives for ShareBox. meta-sharebox is an open source layer:
whoever builds and places ShareBox devices on the market (the
manufacturer in CRA terms) remains responsible for their own conformity
assessment, signing keys and support commitments. This layer provides the
technical material for it.

Status: prototype, no release yet. Items marked "to do" are not available.

## Index

| CRA topic | Where | Status |
| --- | --- | --- |
| Product description, intended use | [`README.md`](../README.md), [`ARCHITECTURE.md`](ARCHITECTURE.md) | available |
| Cybersecurity risk assessment | [`threat-model.md`](threat-model.md) | available, to be reviewed after hardware tests |
| Attack surface: ports, services, users | [`ports-and-services.md`](ports-and-services.md) | available |
| Secure by default configuration | [`threat-model.md`](threat-model.md) (mitigations), [`kernel-hardening.md`](kernel-hardening.md), [`ARCHITECTURE.md`](ARCHITECTURE.md) (unit hardening) | available |
| Deviations from the design, with reasons | [`deviations.md`](deviations.md) | available |
| Software bill of materials | SPDX 3.0 SBOM per image and per version (below) | produced by every build |
| Vulnerability handling and disclosure policy | [`SECURITY.md`](../SECURITY.md) | available |
| Single point of contact for vulnerability reports | GitHub private security advisories, <https://github.com/mgdx/meta-sharebox/security/advisories/new> | available |
| Security updates and their delivery | [`updates.md`](updates.md), [`SECURITY.md`](../SECURITY.md) | available (USB stick, signed RAUC bundles) |
| Support period | [`SECURITY.md`](../SECURITY.md): until April 2030 (end of Yocto 6.0 Wrynose LTS) | available |
| Release notes | [`CHANGELOG.md`](../CHANGELOG.md) | available |
| Test reports (acceptance tests, footprint, hardening tools) | CI artefacts, `scripts/test-target.sh` output | to do: no hardware run yet |
| User information on secure use | [`README.md`](../README.md) (customization, updates), home page "How it works" | partial |

## SBOM per version

Every image build produces, in `tmp/deploy/images/<machine>/`:

- `sharebox-image-<engine>-<machine>.rootfs.spdx.json`: SPDX 3.0 SBOM
  (`create-spdx`, `SPDX_PRETTY = "1"`), with the sources of every package
  when `SPDX_INCLUDE_SOURCES = "1"` (the default for release builds) and
  VEX statements for CVEs (`SPDX_INCLUDE_VEX = "all"`, from `CVE_STATUS`).
- `...rootfs.sbom-cve-check.spdx.json`, `...rootfs.sbom-cve-check.yocto.json`
  and `...rootfs.cve.txt`: the vulnerability scan of that SBOM
  (`sbom-cve-check`, CVEProject cvelistV5 and NVD feeds).
- `...rootfs.manifest`: list of installed packages and versions.

For a release, these files are published for every image and machine
together with the SD card image (`.wic.gz`, `.wic.bmap`), the update bundle
(`.raucb`) and a SHA-256 checksum file (signing that file: to do). The
`build` workflow (`.github/workflows/build.yml`) collects them as artefacts
of each build. The version is `DISTRO_VERSION` (`conf/distro/sharebox.conf`),
shown in `/etc/os-release` and on the `/status` page; the RAUC bundle carries
the same version.

## Update policy

- At least one release per quarter, following the Wrynose stable updates.
- A corrective release within 14 days for a critical CVE on hostapd,
  dnsmasq, lighttpd, the kernel or a sharing engine (`SECURITY.md`).
- Updates are signed RAUC bundles installed offline from a USB stick, after
  an explicit confirmation on the `/status` page, with automatic rollback
  if the new version does not come up ([`updates.md`](updates.md)).
- `/data` content (shared files, ZIM files, chat history, configuration) is
  not part of the bundles and is kept across updates.
- Images built with `SHAREBOX_UPDATES = "0"` have no update mechanism: the
  manufacturer must then provide reflashing as the update path.
- Signing keys: the layer's development keys are public and only for
  development; production keys are generated and kept by the manufacturer
  ([`files/rauc-keys/README.md`](../files/rauc-keys/README.md)).

## Support period

Aligned with the Yocto Project 6.0 "Wrynose" LTS: **until April 2030**.
Upstream security fixes for oe-core and the other Wrynose layers stop at
that date; supporting devices beyond it requires moving to the next LTS.

## Vulnerability handling

See [`SECURITY.md`](../SECURITY.md): private reporting through GitHub
security advisories, acknowledgement within 5 working days, CVE scan at
every build, `CVE_STATUS` for non-applicable CVEs, public advisory with the
fix.

## Build reproducibility and supply chain

- Layer and dependency commits pinned in `kas/common.yml`.
- Sources pinned (`SRCREV` on tags, checksums, generated Rust crate and Go
  module lists), see `ARCHITECTURE.md`, "Recipe rules".
- `BUILD_REPRODUCIBLE_BINARIES` (oe-core default). The weekly
  `oe-selftest -r reproducible` run on `sharebox-image-modular` for
  `raspberrypi4-64` planned by the specification is to do (it needs the
  self-hosted runner).
- Interpreters are forbidden in images (`SHAREBOX_FORBIDDEN_PACKAGES`,
  checked at build time and by `scripts/check-forbidden-packages.sh`).
