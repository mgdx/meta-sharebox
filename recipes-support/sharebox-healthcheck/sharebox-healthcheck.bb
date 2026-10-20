SUMMARY = "ShareBox boot health check for A/B updates"
DESCRIPTION = "Waits for hostapd, dnsmasq and the port 80 front end, then \
marks the booted RAUC slot good. Rolls back a freshly installed slot that \
does not become healthy. Does nothing when rauc is not installed."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://sharebox-healthcheck \
    file://sharebox-healthcheck.service \
"

S = "${UNPACKDIR}"

inherit allarch systemd features_check

REQUIRED_DISTRO_FEATURES = "systemd"

SYSTEMD_SERVICE:${PN} = "sharebox-healthcheck.service"

do_install() {
    install -d ${D}${nonarch_libdir}/sharebox
    install -m 0755 ${S}/sharebox-healthcheck ${D}${nonarch_libdir}/sharebox/
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/sharebox-healthcheck.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} = "${nonarch_libdir}/sharebox ${systemd_system_unitdir}"

# rauc is deliberately not a runtime dependency: the unit is skipped when
# rauc is absent (ConditionPathExists=/usr/bin/rauc).
