SUMMARY = "gamja, a simple static web IRC client"
DESCRIPTION = "gamja is a lightweight IRC client for web browsers. ShareBox \
serves it at /chat/ and points it at the local Ergo server (/socket)."
HOMEPAGE = "https://codeberg.org/emersion/gamja"
BUGTRACKER = "https://codeberg.org/emersion/gamja/issues"
SECTION = "net"

# gamja itself, plus the three runtime libraries it imports in the browser:
# preact (MIT), htm (Apache-2.0) and linkifyjs (MIT).
LICENSE = "AGPL-3.0-only & MIT & Apache-2.0"
LIC_FILES_CHKSUM = " \
    file://LICENSE;md5=4ae09d45eac4aa08d013b5f2e01c67f6 \
    file://node_modules/preact/LICENSE;md5=11497b3621048be9724baca2ec0d85ee \
    file://node_modules/htm/LICENSE;md5=de72828030685f7dd2005bd74de4650c \
    file://node_modules/linkifyjs/LICENSE;md5=8b96a7576d8fa07a67a7300725c0c1e8 \
"

# No release ships a built dist/ (the upstream release tarball is the plain
# source tree, and Parcel builds need Node.js). gamja does not need a bundler
# though: its sources are native ES modules that import their three
# dependencies from node_modules/<pkg>/dist/*.js. Those prebuilt ES module
# files come from the npm registry tarballs pinned below (versions from the
# upstream package-lock.json of this tag), so no Node.js is needed at all.
PV = "1.0.0~beta.11"
SRC_URI = " \
    git://codeberg.org/emersion/gamja.git;protocol=https;nobranch=1;tag=v1.0.0-beta.11 \
    https://registry.npmjs.org/preact/-/preact-10.26.4.tgz;name=preact;subdir=${BB_GIT_DEFAULT_DESTSUFFIX}/node_modules/preact;striplevel=1 \
    https://registry.npmjs.org/htm/-/htm-3.1.1.tgz;name=htm;subdir=${BB_GIT_DEFAULT_DESTSUFFIX}/node_modules/htm;striplevel=1 \
    https://registry.npmjs.org/linkifyjs/-/linkifyjs-4.2.0.tgz;name=linkifyjs;subdir=${BB_GIT_DEFAULT_DESTSUFFIX}/node_modules/linkifyjs;striplevel=1 \
    file://config.json \
    file://50-gamja.conf \
"
SRCREV = "caf6e9978b8db4e4c45b0380f65e7ce825d65e67"
SRC_URI[preact.sha256sum] = "3ee2f67884ecaad0652a3bb75d1b6734518dc276f0af653e9fb2d24bfc441c27"
SRC_URI[htm.sha256sum] = "2425b9bee11409177bcabc7f32e319926fc6690c1701c0b257c88bdff2d5ba90"
SRC_URI[linkifyjs.sha256sum] = "62945f6d454936006dc291c139546b27c493f486e9d76e3780f796a8f30ba63e"

inherit allarch

do_configure[noexec] = "1"
do_compile[noexec] = "1"

GAMJA_DIR = "${datadir}/gamja"

do_install() {
    install -d ${D}${GAMJA_DIR}
    for f in index.html main.js style.css manifest.json commands.js \
             keybindings.js state.js store.js; do
        install -m 0644 ${S}/$f ${D}${GAMJA_DIR}/$f
    done
    for d in components lib; do
        install -d ${D}${GAMJA_DIR}/$d
        install -m 0644 ${S}/$d/*.js ${D}${GAMJA_DIR}/$d/
    done

    # Only the ES module builds imported by lib/index.js, plus licenses
    install -d ${D}${GAMJA_DIR}/node_modules/preact/dist \
               ${D}${GAMJA_DIR}/node_modules/htm/dist \
               ${D}${GAMJA_DIR}/node_modules/linkifyjs/dist
    install -m 0644 ${S}/node_modules/preact/dist/preact.module.js ${D}${GAMJA_DIR}/node_modules/preact/dist/
    install -m 0644 ${S}/node_modules/htm/dist/htm.module.js ${D}${GAMJA_DIR}/node_modules/htm/dist/
    install -m 0644 ${S}/node_modules/linkifyjs/dist/linkify.es.js ${D}${GAMJA_DIR}/node_modules/linkifyjs/dist/
    for p in preact htm linkifyjs; do
        install -m 0644 ${S}/node_modules/$p/LICENSE ${D}${GAMJA_DIR}/node_modules/$p/LICENSE
    done

    install -m 0644 ${UNPACKDIR}/config.json ${D}${GAMJA_DIR}/config.json

    install -d ${D}${sysconfdir}/lighttpd/conf.d
    install -m 0644 ${UNPACKDIR}/50-gamja.conf ${D}${sysconfdir}/lighttpd/conf.d/50-gamja.conf
}

PACKAGES =+ "${PN}-lighttpd"

FILES:${PN} = "${GAMJA_DIR}"
FILES:${PN}-lighttpd = "${sysconfdir}/lighttpd/conf.d/50-gamja.conf"

RDEPENDS:${PN}-lighttpd = "${PN} lighttpd"
