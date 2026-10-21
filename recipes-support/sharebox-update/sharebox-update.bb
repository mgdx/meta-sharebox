SUMMARY = "ShareBox offline updates from USB sticks"
DESCRIPTION = "usb-automount hook that verifies RAUC bundles found on USB \
sticks (sharebox/*.raucb) and records them for the /status page, and the \
sharebox-install-update command that installs the confirmed bundle and \
reboots. Only installed when SHAREBOX_UPDATES = \"1\"."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://50-rauc \
    file://sharebox-install-update \
    file://sharebox-update-lib.sh \
    file://sharebox-update-install.path \
    file://sharebox-update-install.service \
    file://sharebox-update.tmpfiles \
"

S = "${UNPACKDIR}"

inherit allarch systemd features_check

REQUIRED_DISTRO_FEATURES = "systemd rauc"

# sharebox-update-install.service is only started by the path unit
SYSTEMD_SERVICE:${PN} = "sharebox-update-install.path"

do_install() {
    install -d ${D}${nonarch_libdir}/sharebox/usb-hooks.d
    install -m 0755 ${S}/50-rauc ${D}${nonarch_libdir}/sharebox/usb-hooks.d/
    install -m 0755 ${S}/sharebox-install-update ${D}${nonarch_libdir}/sharebox/
    install -m 0644 ${S}/sharebox-update-lib.sh ${D}${nonarch_libdir}/sharebox/
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/sharebox-update-install.path ${S}/sharebox-update-install.service \
        ${D}${systemd_system_unitdir}/
    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${S}/sharebox-update.tmpfiles ${D}${nonarch_libdir}/tmpfiles.d/sharebox-update.conf
}

FILES:${PN} = " \
    ${nonarch_libdir}/sharebox \
    ${nonarch_libdir}/tmpfiles.d \
    ${systemd_system_unitdir} \
"

RDEPENDS:${PN} = "rauc"
