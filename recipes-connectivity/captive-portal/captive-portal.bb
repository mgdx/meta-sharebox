SUMMARY = "ShareBox captive portal rules for lighttpd"
DESCRIPTION = "lighttpd snippet answering the captive portal probes of \
Android, ChromeOS, iOS/macOS, Windows, Firefox, NetworkManager, KDE and \
Ubuntu: 'popup' mode redirects them to the home page (sign-in window), \
'silent' mode answers them like a network with Internet access."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://10-captive.conf \
    file://popup.conf \
    file://silent.conf \
    file://probes \
"

S = "${UNPACKDIR}"

inherit allarch

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${sysconfdir}/lighttpd/conf.d ${D}${datadir}/captive-portal/probes
    install -m 0644 ${S}/10-captive.conf ${D}${sysconfdir}/lighttpd/conf.d/
    install -m 0644 ${S}/popup.conf ${S}/silent.conf ${D}${datadir}/captive-portal/
    for f in ${S}/probes/*; do
        case $f in
            *.cgi) install -m 0755 $f ${D}${datadir}/captive-portal/probes/ ;;
            *) install -m 0644 $f ${D}${datadir}/captive-portal/probes/ ;;
        esac
    done
}

FILES:${PN} = "${sysconfdir}/lighttpd/conf.d ${datadir}/captive-portal"
RDEPENDS:${PN} = "lighttpd lighttpd-module-cgi sharebox-config"
