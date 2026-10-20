SUMMARY = "Mustache text templates for modern C++ (header only)"
DESCRIPTION = "Header-only C++ implementation of the Mustache template \
language by Kevin Wojniak, used by libkiwix to render its HTML pages."
HOMEPAGE = "https://github.com/kainjow/Mustache"
SECTION = "devel"

LICENSE = "BSL-1.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9df08b19634b86f9db5ebbe1fd26ead3"

# libkiwix requires Mustache 4.1 or later (see its README).
SRC_URI = "git://github.com/kainjow/Mustache.git;protocol=https;branch=master;tag=v${PV}"
SRCREV = "c66fdd87f01f0b2d1ba704192f27355b77746a5b"

inherit allarch

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${includedir}
    install -m 0644 ${S}/mustache.hpp ${D}${includedir}/mustache.hpp
}

# Header only: everything goes to the -dev package, the main package is empty.
ALLOW_EMPTY:${PN} = "1"
RDEPENDS:${PN}-dev = ""

BBCLASSEXTEND = "native nativesdk"
