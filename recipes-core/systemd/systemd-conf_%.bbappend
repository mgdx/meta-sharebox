# ShareBox: volatile journal; no DHCP client on Ethernet in production (the
# box never joins another network; the dev profile keeps it for SSH).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://journald-sharebox.conf"

PACKAGECONFIG:remove = "${@'' if d.getVar('SHAREBOX_DEV') == '1' else 'dhcp-ethernet'}"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/journald-sharebox.conf ${D}${systemd_unitdir}/journald.conf.d/10-sharebox.conf
}
