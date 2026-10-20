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
    file://50-dufs-ro.conf \
    file://50-dufs-upload.conf \
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
    for f in 50-dufs.conf 50-dufs-ro.conf 50-dufs-upload.conf; do
        install -m 0644 ${UNPACKDIR}/$f ${D}${sysconfdir}/lighttpd/conf.d/$f
    done
}

# Packages and the images that use them:
#   dufs                  binary and the "sharebox" user (all)
#   dufs-rw               dufs.service, writable instance on 127.0.0.1:5000:
#                         whole share at /files/ (modular) or only the upload
#                         directory at /upload/ (SHAREBOX_ENGINE=full)
#   dufs-ro               dufs-ro.service, read-only share on 127.0.0.1:5001
#                         (library, full)
#   dufs-lighttpd         /files/ -> 5000 (modular)
#   dufs-ro-lighttpd      /files/ -> 5001 (library, full)
#   dufs-upload-lighttpd  /upload/ -> 5000 (full)
# dufs-lighttpd and dufs-ro-lighttpd claim the same URL and conflict.
PACKAGES =+ "${PN}-rw ${PN}-ro ${PN}-lighttpd ${PN}-ro-lighttpd ${PN}-upload-lighttpd"

FILES:${PN}-rw = "${libexecdir}/dufs ${systemd_system_unitdir}/dufs.service"
FILES:${PN}-ro = "${systemd_system_unitdir}/dufs-ro.service"
FILES:${PN}-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-dufs.conf"
FILES:${PN}-ro-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-dufs-ro.conf"
FILES:${PN}-upload-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-dufs-upload.conf"

RDEPENDS:${PN}-rw = "${PN}"
RDEPENDS:${PN}-ro = "${PN}"
RDEPENDS:${PN}-lighttpd = "${PN}-rw lighttpd lighttpd-module-proxy"
RDEPENDS:${PN}-ro-lighttpd = "${PN}-ro lighttpd lighttpd-module-proxy"
RDEPENDS:${PN}-upload-lighttpd = "${PN}-rw lighttpd lighttpd-module-proxy"
RCONFLICTS:${PN}-lighttpd = "${PN}-ro-lighttpd"
RCONFLICTS:${PN}-ro-lighttpd = "${PN}-lighttpd"

SYSTEMD_PACKAGES = "${PN}-rw ${PN}-ro"
SYSTEMD_SERVICE:${PN}-rw = "dufs.service"
SYSTEMD_SERVICE:${PN}-ro = "dufs-ro.service"
SYSTEMD_AUTO_ENABLE = "enable"
