SUMMARY = "Luffy, a single binary Go rewrite of the PirateBox server"
DESCRIPTION = "Luffy serves the PirateBox web interface: file listing, \
droopy compatible anonymous uploads, the shoutbox chat, a flat-file forum \
compatible with forest.py and answers to captive portal probes. In ShareBox \
it is the 'classic' engine and listens on port 80 itself."
HOMEPAGE = "https://github.com/et0and/luffy"
BUGTRACKER = "https://github.com/et0and/luffy/issues"
SECTION = "net"

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://src/${GO_IMPORT}/LICENSE;md5=8848ffd290e07a868ec48919bc47280a"
require ${BPN}-licenses.inc

# Upstream has no release tag yet: pin the last commit of main.
# The version comes from upstream's Makefile (VERSION ?= 1.0.0).
PV = "1.0.0+git"
SRCREV = "9523301d7ad2cedbf7a735b328f3a2d3ef678e66"
SRC_URI = "git://github.com/et0and/luffy.git;protocol=https;branch=main;destsuffix=${GO_SRCURI_DESTSUFFIX} \
           file://0001-Serve-uploads-on-the-main-listener.patch;patchdir=src/${GO_IMPORT} \
           file://luffy.service \
           file://luffy-gen-config \
           file://luffy.tmpfiles \
           "
require ${BPN}-go-mods.inc

# go.mod declares "module luffy" (not the GitHub path).
GO_IMPORT = "luffy"
GO_INSTALL = "${GO_IMPORT}/cmd/luffy"

inherit go-mod go-mod-update-modules systemd useradd

# Pure Go, static binary, reproducible paths. CGO must be exported to reach
# the go tool, and -linkshared (default on arm64) needs cgo, so it is dropped.
export CGO_ENABLED = "0"
GO_LINKSHARED = ""
GOBUILDFLAGS:append = " -trimpath"
GO_EXTRA_LDFLAGS = "-X main.version=${PV}"

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data --shell /sbin/nologin --user-group sharebox"

SYSTEMD_SERVICE:${PN} = "luffy.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/${GO_BUILD_BINDIR}/luffy ${D}${bindir}/luffy

    install -d ${D}${libexecdir}/luffy
    install -m 0755 ${UNPACKDIR}/luffy-gen-config ${D}${libexecdir}/luffy/luffy-gen-config

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/luffy.service ${D}${systemd_system_unitdir}/luffy.service
    sed -i -e 's#@BINDIR@#${bindir}#g' -e 's#@LIBEXECDIR@#${libexecdir}#g' \
        ${D}${systemd_system_unitdir}/luffy.service

    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${UNPACKDIR}/luffy.tmpfiles ${D}${nonarch_libdir}/tmpfiles.d/luffy.conf
}

FILES:${PN} += "${nonarch_libdir}/tmpfiles.d/luffy.conf"

# iw feeds the "connected clients" counter on the start page.
RRECOMMENDS:${PN} = "iw"
