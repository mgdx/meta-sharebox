# Security hardening and supply chain settings shared by all ShareBox images
#
# Compiler hardening (stack protector, PIE, _FORTIFY_SOURCE, relro/now, ...)
# comes from conf/distro/include/security_flags.inc, already required by
# oe-core defaultsetup.conf.

# --- SBOM (SPDX 3.0, the only format in Wrynose) ----------------------------
# create-spdx is already in INHERIT_DISTRO, listed again to make it explicit.
INHERIT += "create-spdx"
# Embedding sources makes the SBOM much larger and slower to produce. Local
# developer builds may set SPDX_INCLUDE_SOURCES = "0" in local.conf.
SPDX_INCLUDE_SOURCES ?= "1"
SPDX_PRETTY ?= "1"

# --- Vulnerability scanning ---------------------------------------------------
# sbom-cve-check (replaces cve-check in Wrynose) runs on the image SBOM after
# do_create_image_sbom_spdx. It needs the CVE databases (CVEProject/cvelistV5
# and fkie-cad/nvd-json-data-feeds git repositories, several GB in DL_DIR).
# Set SHAREBOX_CVE_CHECK = "0" in local.conf to skip it on developer builds.
SHAREBOX_CVE_CHECK ??= "1"
IMAGE_CLASSES:append = "${@' sbom-cve-check' if d.getVar('SHAREBOX_CVE_CHECK') == '1' else ''}"
SBOM_CVE_CHECK_SHOW_WARNINGS = "1"
SBOM_CVE_CHECK_EXPORT_VARS = "SBOM_CVE_CHECK_EXPORT_SPDX3 SBOM_CVE_CHECK_EXPORT_CVECHECK SBOM_CVE_CHECK_EXPORT_SUMMARY"
SPDX_INCLUDE_VEX ?= "all"

# --- QA -------------------------------------------------------------------------
# buildpaths, dev-so and ldflags are already errors in Wrynose; keep them
# explicit so that a future oe-core default change cannot silently relax them.
ERROR_QA:append = " buildpaths dev-so ldflags patch-fuzz"

# --- No interpreters on target ----------------------------------------------------
# Package name prefixes that must never end up in a ShareBox image. Checked
# by sharebox-image.bbclass after the rootfs is assembled.
SHAREBOX_FORBIDDEN_PACKAGES ?= "python3 perl php nodejs"

# nftables would otherwise pull python3 bindings in the build
PACKAGECONFIG:remove:pn-nftables = "python"
