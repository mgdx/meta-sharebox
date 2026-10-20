SUMMARY = "Reference implementation of the ZIM file format"
DESCRIPTION = "libzim reads and writes ZIM files, the offline content format \
used by Kiwix (Wikipedia, Wiktionary, Gutenberg, TED, ...)."
HOMEPAGE = "https://github.com/openzim/libzim"
SECTION = "libs"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=00f62fee8056dc37ed6566f4ab3ddf2a"

DEPENDS = "xz zstd"

SRC_URI = "git://github.com/openzim/libzim.git;protocol=https;branch=main;tag=${PV}"
SRCREV = "26ec526f74e8342a40da5ab14e364546988e0e1a"

inherit meson pkgconfig

# Full-text search (Xapian). libkiwix refuses to build against a libzim
# without Xapian, so this must stay enabled as long as libkiwix/kiwix-tools
# are built. It is only kept as a knob for reader-only users of libzim.
# ICU is only used by the Xapian indexer/searcher.
PACKAGECONFIG ??= "xapian"
PACKAGECONFIG[xapian] = "-Dwith_xapian=true,-Dwith_xapian=false,xapian-core icu"

# Upstream defaults to werror=true, which breaks with every new GCC release.
# Tests need gtest and test ZIM files downloaded at configure time, examples
# are not installed: disable both.
EXTRA_OEMESON = " \
    -Dwerror=false \
    -Dtests=false \
    -Dexamples=false \
    -Ddoc=false \
"

BBCLASSEXTEND = "native nativesdk"
