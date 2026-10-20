SUMMARY = "Common code base of the Kiwix offline content readers"
DESCRIPTION = "libkiwix provides the library management, OPDS catalog and \
embedded HTTP server used by kiwix-serve and kiwix-manage."
HOMEPAGE = "https://github.com/kiwix/libkiwix"
SECTION = "libs"

LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=4c61b8950dc1aab4d2aa7c2ae6b1cfb3"

# Xapian is mandatory: meson.build checks LIBZIM_WITH_XAPIAN and errors out.
DEPENDS = " \
    libzim \
    xapian-core \
    icu \
    pugixml \
    curl \
    libmicrohttpd \
    zlib \
    kainjow-mustache \
"

SRC_URI = "git://github.com/kiwix/libkiwix.git;protocol=https;branch=main;tag=${PV}"
SRCREV = "46b599fb2c88cf55b0f889971aa9c930cdae94cd"

inherit meson pkgconfig

# The resource compilers are Python scripts run from the source tree at build
# time (with python3-native, already required by meson). Tests are skipped by
# upstream when cross compiling and the gtest wrap is never downloaded
# (--wrap-mode=nodownload).
EXTRA_OEMESON = " \
    -Dwerror=false \
    -Ddoc=false \
"

do_install:append() {
    # Build helpers for other Kiwix projects: Python scripts that must not
    # end up on the target (no Python on ShareBox images).
    rm -f ${D}${bindir}/kiwix-compile-resources ${D}${bindir}/kiwix-compile-i18n
    rmdir --ignore-fail-on-non-empty ${D}${bindir} 2>/dev/null || true
    rm -rf ${D}${mandir}
}
