SUMMARY = "Distinctive utility file server with WebDAV, search and resumable upload"
DESCRIPTION = "dufs serves a directory over HTTP with a web UI, WebDAV, \
search, zip download of folders and resumable uploads. ShareBox uses it \
behind lighttpd for the public share (/files/)."
HOMEPAGE = "https://github.com/sigoden/dufs"
BUGTRACKER = "https://github.com/sigoden/dufs/issues"
SECTION = "net"

LICENSE = "MIT | Apache-2.0"
LIC_FILES_CHKSUM = " \
    file://LICENSE-MIT;md5=9199737ff2ab92d7b6563683af8fed3b \
    file://LICENSE-APACHE;md5=53b31fd1a4531d803a424ac75374f447 \
"

SRC_URI = " \
    git://github.com/sigoden/dufs.git;protocol=https;nobranch=1;tag=v${PV} \
    file://dufs-start \
    file://dufs.service \
    file://dufs-ro.service \
    file://50-dufs.conf \
"
SRCREV = "225f2542670d8f5a58a9f5fe918791f0987759c8"

require ${BPN}-crates.inc

inherit cargo cargo-update-recipe-crates systemd useradd

# TLS is terminated nowhere on the box (offline, plain HTTP behind lighttpd):
# build without rustls/ring. PACKAGECONFIG "tls" restores the upstream default.
CARGO_BUILD_FLAGS += "--no-default-features"
PACKAGECONFIG ??= ""
PACKAGECONFIG[tls] = "--features tls"

# The upstream release profile (opt-level s, lto, codegen-units 1,
# panic = abort) is kept, except "strip": stripping is left to
# do_package so that the -dbg package and QA checks keep working.
export CARGO_PROFILE_RELEASE_STRIP = "false"

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data --shell /sbin/nologin --user-group sharebox"

do_install:append() {
    install -d ${D}${libexecdir}/dufs
    install -m 0755 ${UNPACKDIR}/dufs-start ${D}${libexecdir}/dufs/dufs-start

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/dufs.service ${D}${systemd_system_unitdir}/dufs.service
    install -m 0644 ${UNPACKDIR}/dufs-ro.service ${D}${systemd_system_unitdir}/dufs-ro.service
    sed -i -e 's#/usr/libexec/#${libexecdir}/#' -e 's#/usr/bin/#${bindir}/#' \
        ${D}${systemd_system_unitdir}/dufs.service \
        ${D}${systemd_system_unitdir}/dufs-ro.service \
        ${D}${libexecdir}/dufs/dufs-start

    install -d ${D}${sysconfdir}/lighttpd/conf.d
    install -m 0644 ${UNPACKDIR}/50-dufs.conf ${D}${sysconfdir}/lighttpd/conf.d/50-dufs.conf
}

# dufs: binary + read-write public share unit (modular engine)
# dufs-ro: read-only unit on port 5001 (library and full engines)
# dufs-lighttpd: /files/ reverse proxy snippet for the dufs unit
PACKAGES =+ "${PN}-ro ${PN}-lighttpd"

FILES:${PN} += "${libexecdir}/dufs ${systemd_system_unitdir}/dufs.service"
FILES:${PN}-ro = "${systemd_system_unitdir}/dufs-ro.service"
FILES:${PN}-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-dufs.conf"

RDEPENDS:${PN}-ro = "${PN}"
RDEPENDS:${PN}-lighttpd = "lighttpd lighttpd-module-proxy"

SYSTEMD_PACKAGES = "${PN} ${PN}-ro"
SYSTEMD_SERVICE:${PN} = "dufs.service"
SYSTEMD_SERVICE:${PN}-ro = "dufs-ro.service"
SYSTEMD_AUTO_ENABLE = "enable"
