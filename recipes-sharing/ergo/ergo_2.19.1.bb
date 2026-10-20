SUMMARY = "Ergo, a modern IRC server with integrated services and history"
DESCRIPTION = "Ergo is an IRC server written in Go with built-in bouncer \
features, message history and a WebSocket listener. ShareBox runs it as a \
local, anonymous chat network reached through lighttpd at /socket."
HOMEPAGE = "https://ergo.chat/"
BUGTRACKER = "https://github.com/ergochat/ergo/issues"
SECTION = "net"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=d7da545aee51742af217e62c42d6dab5"
require ${BPN}-licenses.inc

SRC_URI = " \
    git://github.com/ergochat/ergo.git;protocol=https;nobranch=1;tag=v${PV};destsuffix=${GO_SRCURI_DESTSUFFIX} \
    file://ircd.yaml \
    file://ergo.motd \
    file://ergo.service \
    file://50-ergo.conf \
"
SRCREV = "63c743a70644f0f19109508ade8580bf37f7d23d"

# Ergo commits its dependencies in vendor/ (with vendor/modules.txt), so the
# Go tool builds offline with -mod=vendor and no gomod:// fetching is needed.
# ergo-licenses.inc lists the licenses of the vendored modules that are
# linked into the binary (see the header of that file to regenerate it).
inherit go-mod systemd useradd

GO_IMPORT = "github.com/ergochat/ergo"
GO_INSTALL = "${GO_IMPORT}"
GO_LINKSHARED = ""

# Pure Go build: the SQLite history backend uses modernc.org/sqlite, which
# needs no CGO. "i18n" is left out (server messages in English only),
# "mysql" and "postgresql" are not used on the box.
export CGO_ENABLED = "0"
ERGO_BUILD_TAGS ?= "sqlite"
GOBUILDFLAGS:prepend = "-mod=vendor -tags=${@','.join(d.getVar('ERGO_BUILD_TAGS').split())} "
GO_EXTRA_LDFLAGS = "-X main.version=v${PV} -X main.commit=${SRCREV}"

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data/chat --shell /sbin/nologin --user-group ergo"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/${GO_BUILD_BINDIR}/ergo ${D}${bindir}/ergo

    install -d ${D}${sysconfdir}/ergo
    install -m 0644 ${UNPACKDIR}/ircd.yaml ${D}${sysconfdir}/ergo/ircd.yaml
    install -m 0644 ${UNPACKDIR}/ergo.motd ${D}${sysconfdir}/ergo/ergo.motd

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/ergo.service ${D}${systemd_system_unitdir}/ergo.service
    sed -i -e 's#/usr/bin/#${bindir}/#' ${D}${systemd_system_unitdir}/ergo.service

    install -d ${D}${sysconfdir}/lighttpd/conf.d
    install -m 0644 ${UNPACKDIR}/50-ergo.conf ${D}${sysconfdir}/lighttpd/conf.d/50-ergo.conf
}

PACKAGES =+ "${PN}-lighttpd"

FILES:${PN} += "${systemd_system_unitdir}/ergo.service"
FILES:${PN}-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-ergo.conf"
CONFFILES:${PN} = "${sysconfdir}/ergo/ircd.yaml ${sysconfdir}/ergo/ergo.motd"

RDEPENDS:${PN}-lighttpd = "lighttpd lighttpd-module-proxy"

SYSTEMD_SERVICE:${PN} = "ergo.service"
SYSTEMD_AUTO_ENABLE = "enable"
