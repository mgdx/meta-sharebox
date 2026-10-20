# ShareBox: configuration generated at boot into /run/sharebox/dnsmasq.conf
# (wildcard DNS, DHCP on wlan0), dedicated user, hardened unit.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://dnsmasq-sharebox.service"

# No TFTP, no scripts, no ipset, no authoritative zones, no DHCPv6 (IPv6 is
# not announced), no dumpfile. Keeps dhcp, inotify and loop detection.
PACKAGECONFIG:remove = "auth dumpfile ipset script tftp dhcp6"

inherit useradd
USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /nonexistent --shell /sbin/nologin --user-group dnsmasq"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/dnsmasq-sharebox.service ${D}${systemd_unitdir}/system/dnsmasq.service
    # Not used: the configuration lives in /run/sharebox, no systemd-resolved
    rm -f ${D}${sysconfdir}/dnsmasq.conf
    rm -rf ${D}${sysconfdir}/systemd/resolved.conf.d ${D}${sysconfdir}/init.d
    rmdir ${D}${sysconfdir}/systemd 2>/dev/null || true
    install -d ${D}${nonarch_libdir}/tmpfiles.d
    echo 'd /run/dnsmasq 0755 dnsmasq dnsmasq -' > ${D}${nonarch_libdir}/tmpfiles.d/dnsmasq.conf
}

FILES:${PN} += "${nonarch_libdir}/tmpfiles.d/dnsmasq.conf"

CONFFILES:${PN} = ""
RDEPENDS:${PN} += "sharebox-config"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
