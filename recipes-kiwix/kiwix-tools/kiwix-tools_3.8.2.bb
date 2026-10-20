SUMMARY = "Kiwix command line tools: kiwix-serve, kiwix-manage, kiwix-search"
DESCRIPTION = "kiwix-serve is an HTTP server for ZIM files (Wikipedia and \
other offline content). kiwix-manage maintains the XML library it serves."
HOMEPAGE = "https://github.com/kiwix/kiwix-tools"
SECTION = "net"

LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=f27defe1e96c2e1ecd4e0c9be8967949"

DEPENDS = "libkiwix libzim docopt.cpp"

SRC_URI = " \
    git://github.com/kiwix/kiwix-tools.git;protocol=https;branch=main;tag=${PV} \
    file://kiwix-serve.service \
    file://kiwix-library-update.service \
    file://kiwix-library-update \
    file://60-kiwix \
    file://50-kiwix.conf \
"
SRCREV = "f76e38bdc06b86b73ba8e84a5de234a0d6c3fa3d"

inherit meson pkgconfig systemd useradd

EXTRA_OEMESON = " \
    -Dwerror=false \
    -Ddoc=false \
    -Dstatic-linkage=false \
"

# Hard memory limit of kiwix-serve (systemd MemoryMax=). Full-text search on
# big ZIM files is the main consumer; see docs/deviations.md.
KIWIX_SERVE_MEMORY_MAX ??= "512M"
KIWIX_SERVE_MEMORY_MAX:raspberrypi0-2w-64 ??= "256M"
KIWIX_SERVE_MEMORY_MAX:raspberrypi3-64 ??= "384M"
KIWIX_SERVE_MEMORY_MAX:raspberrypi5 ??= "1G"

# The MemoryMax= value above is machine specific.
PACKAGE_ARCH = "${MACHINE_ARCH}"

SHAREBOX_USB_HOOKS_DIR = "${nonarch_libdir}/sharebox/usb-hooks.d"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/kiwix-serve.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/kiwix-library-update.service ${D}${systemd_system_unitdir}/
    sed -i -e 's,@MEMORY_MAX@,${KIWIX_SERVE_MEMORY_MAX},g' \
           -e 's,@BINDIR@,${bindir},g' \
        ${D}${systemd_system_unitdir}/kiwix-serve.service \
        ${D}${systemd_system_unitdir}/kiwix-library-update.service

    install -m 0755 ${UNPACKDIR}/kiwix-library-update ${D}${bindir}/kiwix-library-update

    install -d ${D}${SHAREBOX_USB_HOOKS_DIR}
    install -m 0755 ${UNPACKDIR}/60-kiwix ${D}${SHAREBOX_USB_HOOKS_DIR}/60-kiwix

    install -d ${D}${sysconfdir}/lighttpd/conf.d
    install -m 0644 ${UNPACKDIR}/50-kiwix.conf ${D}${sysconfdir}/lighttpd/conf.d/50-kiwix.conf
}

# kiwix-search is only useful for debugging and is not pulled by any
# packagegroup. The main package is a meta package for serve + manage.
PACKAGE_BEFORE_PN = "kiwix-serve kiwix-manage kiwix-search ${PN}-lighttpd"

ALLOW_EMPTY:${PN} = "1"
RDEPENDS:${PN} = "kiwix-serve kiwix-manage"

FILES:kiwix-serve = "${bindir}/kiwix-serve ${systemd_system_unitdir}/kiwix-serve.service"
FILES:kiwix-manage = " \
    ${bindir}/kiwix-manage \
    ${bindir}/kiwix-library-update \
    ${systemd_system_unitdir}/kiwix-library-update.service \
    ${SHAREBOX_USB_HOOKS_DIR}/60-kiwix \
"
FILES:kiwix-search = "${bindir}/kiwix-search"
FILES:${PN}-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-kiwix.conf"
CONFFILES:${PN}-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-kiwix.conf"

# kiwix-serve reads library.xml produced by kiwix-library-update.
RDEPENDS:kiwix-serve = "kiwix-manage"
RDEPENDS:${PN}-lighttpd = "kiwix-serve"

SYSTEMD_PACKAGES = "kiwix-serve kiwix-manage"
SYSTEMD_SERVICE:kiwix-serve = "kiwix-serve.service"
SYSTEMD_SERVICE:kiwix-manage = "kiwix-library-update.service"

USERADD_PACKAGES = "kiwix-serve kiwix-manage"
USERADD_PARAM:kiwix-serve = "--system --no-create-home --home-dir /data/zim --shell /sbin/nologin --user-group kiwix"
USERADD_PARAM:kiwix-manage = "${USERADD_PARAM:kiwix-serve}"
