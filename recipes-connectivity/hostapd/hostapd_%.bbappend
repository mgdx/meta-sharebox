# ShareBox: reduced build (open AP only), configuration generated at boot by
# sharebox-setup into /run/sharebox/hostapd.conf, hardened unit, enabled.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

do_install:append() {
    # The example configuration is never used
    rm -f ${D}${sysconfdir}/hostapd.conf
    rm -rf ${D}${sysconfdir}/init.d
}

CONFFILES:${PN}:remove = "${sysconfdir}/hostapd.conf"

RDEPENDS:${PN} += "sharebox-config"

SYSTEMD_AUTO_ENABLE:${PN} = "enable"
