SUMMARY = "ShareBoxx anonymous offline file sharing and chat server"
DESCRIPTION = "ShareBoxx is a Rust (Leptos, actix-web) web application for \
anonymous offline file sharing and chat over Wi-Fi. This recipe builds the \
server side rendering binary; the WebAssembly client bundle comes from \
shareboxx-web. In ShareBox it is the 'shareboxx' engine and listens on \
port 80 itself."
HOMEPAGE = "https://github.com/dividebysandwich/shareboxx"
BUGTRACKER = "https://github.com/dividebysandwich/shareboxx/issues"
SECTION = "net"

# ShareBoxx is GPL-2.0-only. The statically linked crates are MIT or
# dual/multi licensed with a GPL-2.0 compatible choice (MIT), plus the
# licenses listed below (see docs/deviations.md, "Shareboxx", for the audit).
LICENSE = "GPL-2.0-only & MIT & BSD-3-Clause & BSL-1.0 & MPL-2.0 & Unicode-3.0 & Zlib & CC0-1.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b234ee4d69f5fce4486a80fdaf4a4263"

SRC_URI = "git://github.com/dividebysandwich/shareboxx.git;protocol=https;nobranch=1;tag=v${PV} \
           file://Cargo.lock;subdir=${BB_GIT_DEFAULT_DESTSUFFIX} \
           file://0001-Make-host-name-and-upload-limit-configurable.patch \
           file://shareboxx.service \
           file://shareboxx.tmpfiles \
           "
SRCREV = "e216e16b730c19eefee36d8cec1f0740458d3aea"

require ${BPN}-crates.inc

inherit cargo cargo-update-recipe-crates systemd useradd

# Server build only: the "ssr" feature, as cargo-leptos does with
# bin-features = ["ssr"] and bin-default-features = false.
EXTRA_OECARGO_BUILD_ARGS = "--no-default-features --features ssr --bin shareboxx"
do_compile() {
    oe_cargo_build ${EXTRA_OECARGO_BUILD_ARGS}
}

# What cargo-leptos exports when it builds the server, needed for the server
# to match the prebuilt client bundle of shareboxx-web:
# - LEPTOS_OUTPUT_NAME at compile time makes the hydration script load
#   pkg/shareboxx.wasm instead of pkg/shareboxx_bg.wasm.
# - Server function URLs end with a hash of CARGO_MANIFEST_DIR. The client
#   bundle was built by upstream CI in /home/runner/work/shareboxx/shareboxx;
#   SERVER_FN_OVERRIDE_KEY replaces CARGO_MANIFEST_DIR in that hash so the
#   server registers the same /api/<name>12246998792517303403 endpoints.
export LEPTOS_OUTPUT_NAME = "shareboxx"
export SERVER_FN_OVERRIDE_KEY = "/home/runner/work/shareboxx/shareboxx"

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data --shell /sbin/nologin --user-group sharebox"

SYSTEMD_SERVICE:${PN} = "shareboxx.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SHAREBOXX_SITEDIR = "${datadir}/shareboxx/site"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/target/${CARGO_TARGET_SUBDIR}/shareboxx ${D}${bindir}/shareboxx

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/shareboxx.service ${D}${systemd_system_unitdir}/shareboxx.service
    sed -i -e 's#@BINDIR@#${bindir}#g' -e 's#@SITEDIR@#${SHAREBOXX_SITEDIR}#g' \
        ${D}${systemd_system_unitdir}/shareboxx.service

    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${UNPACKDIR}/shareboxx.tmpfiles ${D}${nonarch_libdir}/tmpfiles.d/shareboxx.conf
}

FILES:${PN} += "${nonarch_libdir}/tmpfiles.d/shareboxx.conf"

# The client bundle, and df for the disk usage widget.
RDEPENDS:${PN} = "shareboxx-web ${VIRTUAL-RUNTIME_base-utils}"
