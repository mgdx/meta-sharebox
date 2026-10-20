SUMMARY = "ShareBoxx client bundle (WebAssembly, JavaScript, CSS)"
DESCRIPTION = "Prebuilt Leptos 'hydrate' client of ShareBoxx, as produced \
by cargo-leptos in upstream's release CI. It is taken from the upstream \
release package because building it would need a wasm32-unknown-unknown \
Rust target, wasm-bindgen-cli and dart-sass (Node.js) in the build. \
See docs/deviations.md, section 'Shareboxx'."
HOMEPAGE = "https://github.com/dividebysandwich/shareboxx"
SECTION = "net"

# shareboxx (GPL-2.0-only) compiled with leptos and friends (MIT) and crates
# dual licensed MIT OR Apache-2.0 (MIT retained).
LICENSE = "GPL-2.0-only & MIT"
LIC_FILES_CHKSUM = "file://${UNPACKDIR}/shareboxx-${PV}-LICENSE;md5=b234ee4d69f5fce4486a80fdaf4a4263"

# The site/ tree is identical in the amd64 and arm64 packages; only the
# arm64 one is fetched. Its server binary is not used: shareboxx builds the
# server from source.
SRC_URI = "https://github.com/dividebysandwich/shareboxx/releases/download/v${PV}/shareboxx_${PV}_arm64.deb;subdir=deb;name=deb \
           https://raw.githubusercontent.com/dividebysandwich/shareboxx/v${PV}/LICENSE;downloadfilename=shareboxx-${PV}-LICENSE;unpack=0;name=license \
           file://shareboxx-web-${PV}.sha256 \
           "
SRC_URI[deb.sha256sum] = "63f261a2e1778fdb2422a37d18fed087e93c65297b2b1e6c6a81c89c8c0a3950"
SRC_URI[license.sha256sum] = "8177f97513213526df2cf6184d8ff986c675afb514d4e68a404010521b880643"

S = "${UNPACKDIR}/deb/var/lib/shareboxx/site"

inherit allarch

do_configure[noexec] = "1"

# Second, per-file check: the assets must be exactly the ones the
# shareboxx server was matched against (server function hash, output name).
do_compile() {
    cd ${S}
    sha256sum -c ${UNPACKDIR}/shareboxx-web-${PV}.sha256
}

do_install() {
    install -d ${D}${datadir}/shareboxx/site/pkg
    for f in favicon.ico file.png folder.png; do
        install -m 0644 ${S}/$f ${D}${datadir}/shareboxx/site/$f
    done
    for f in shareboxx.css shareboxx.js shareboxx.wasm; do
        install -m 0644 ${S}/pkg/$f ${D}${datadir}/shareboxx/site/pkg/$f
    done
}

FILES:${PN} = "${datadir}/shareboxx/site"
