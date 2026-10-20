SUMMARY = "Xapian search engine library"
DESCRIPTION = "Xapian is an Open Source search engine library. It is used by \
libzim to provide full-text search in ZIM archives."
HOMEPAGE = "https://xapian.org/"
SECTION = "libs"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://COPYING;md5=570a9b3749dd0463a1778803b12a6dce"

DEPENDS = "zlib util-linux"

SRC_URI = "https://oligarchy.co.uk/xapian/${PV}/${BP}.tar.xz"
SRC_URI[sha256sum] = "c4fd64e81127311756adf5579268d14a79f285ce8ac4ead0930c96195897aece"

UPSTREAM_CHECK_URI = "https://xapian.org/download"
UPSTREAM_CHECK_REGEX = "xapian-core-(?P<pver>1\.4\.\d+)\.tar"

inherit autotools pkgconfig binconfig-disabled

BINCONFIG = "${bindir}/xapian-config"

# No documentation (it would need doxygen and sphinx).
EXTRA_OECONF = " \
    --disable-documentation \
    --disable-werror \
"

# The command line tools (xapian-delve, quest, ...) are not needed on the box.
PACKAGES =+ "${PN}-bin"
FILES:${PN}-bin = "${bindir}"

BBCLASSEXTEND = "native nativesdk"
