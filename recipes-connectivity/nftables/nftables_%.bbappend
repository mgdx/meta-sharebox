# ShareBox: firewall ruleset and its service (started before hostapd).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://sharebox.nft \
    file://nftables.service \
"

# No python bindings, no interactive CLI (readline is GPL-3.0), no JSON
PACKAGECONFIG = ""

inherit systemd

do_install:append() {
    install -d ${D}${sysconfdir}/nftables ${D}${sysconfdir}/nftables.d
    install -m 0644 ${UNPACKDIR}/sharebox.nft ${D}${sysconfdir}/nftables/sharebox.nft
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/nftables.service ${D}${systemd_system_unitdir}/nftables.service
}

FILES:${PN} += "${sysconfdir}/nftables ${sysconfdir}/nftables.d ${systemd_system_unitdir}/nftables.service"

SYSTEMD_SERVICE:${PN} = "nftables.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# Kernel side of the ruleset (built as modules by default on the Pi)
RRECOMMENDS:${PN} += " \
    kernel-module-nf-tables \
    kernel-module-nft-ct \
    kernel-module-nft-limit \
    kernel-module-nft-redir \
    kernel-module-nft-reject \
    kernel-module-nft-reject-inet \
    kernel-module-nft-chain-nat \
    kernel-module-nf-nat \
    kernel-module-nf-conntrack \
"
