SUMMARY = "ShareBox USB stick automount"
DESCRIPTION = "udev rule mounting USB sticks read-only under \
/media/usb-<label> with systemd-mount (automount, collected on removal), \
and sharebox-usb-scan.service which exposes the newest stick as \
/data/share/usb, imports sharebox/sharebox.conf and runs the hooks of \
/usr/lib/sharebox/usb-hooks.d (RAUC bundle detection). udisks2 is not used."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://99-sharebox-usb.rules \
    file://usb-mount \
    file://sharebox-usb-scan \
    file://sharebox-usb-scan.service \
    file://media.mount \
"

S = "${UNPACKDIR}"

inherit allarch systemd

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${nonarch_base_libdir}/udev/rules.d ${D}${nonarch_libdir}/sharebox/usb-hooks.d \
        ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/99-sharebox-usb.rules ${D}${nonarch_base_libdir}/udev/rules.d/
    install -m 0755 ${S}/usb-mount ${S}/sharebox-usb-scan ${D}${nonarch_libdir}/sharebox/
    install -m 0644 ${S}/sharebox-usb-scan.service ${S}/media.mount ${D}${systemd_system_unitdir}/
}

FILES:${PN} = " \
    ${nonarch_base_libdir}/udev/rules.d \
    ${nonarch_libdir}/sharebox \
    ${systemd_system_unitdir} \
"

SYSTEMD_SERVICE:${PN} = "media.mount sharebox-usb-scan.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} = "sharebox-config"

# File systems accepted on sticks (no-op when built into the kernel)
RRECOMMENDS:${PN} = " \
    kernel-module-exfat \
    kernel-module-ntfs3 \
    kernel-module-vfat \
    kernel-module-nls-utf8 \
    kernel-module-nls-cp437 \
    kernel-module-nls-iso8859-1 \
    kernel-module-uas \
    kernel-module-usb-storage \
"
