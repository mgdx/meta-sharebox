SUMMARY = "ShareBox storage helpers: data partition growth and fsck settings"
DESCRIPTION = "Grows the /data partition to the end of the card at first boot \
and provides the e2fsck configuration used by the ShareBox preinit. \
Installed in every image by sharebox-storage.bbclass."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://sharebox-grow-data \
    file://sharebox-grow-data.service \
    file://e2fsck.conf \
"

S = "${UNPACKDIR}"

inherit allarch systemd features_check

REQUIRED_DISTRO_FEATURES = "systemd"

SYSTEMD_SERVICE:${PN} = "sharebox-grow-data.service"

do_install() {
    install -d ${D}${nonarch_libdir}/sharebox
    install -m 0755 ${S}/sharebox-grow-data ${D}${nonarch_libdir}/sharebox/
    install -m 0644 ${S}/e2fsck.conf ${D}${nonarch_libdir}/sharebox/
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/sharebox-grow-data.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} = "${nonarch_libdir}/sharebox ${systemd_system_unitdir}"

# e2fsck: data partition check in the preinit; sfdisk, partx, resize2fs:
# online growth
RDEPENDS:${PN} = " \
    e2fsprogs-e2fsck \
    e2fsprogs-resize2fs \
    util-linux-sfdisk \
    util-linux-partx \
"
