SUMMARY = "ShareBox library engine: Kiwix offline content and read-only file share"
DESCRIPTION = "kiwix-serve (ZIM files under /wiki/), kiwix-manage and the \
library rebuild service, plus a read-only dufs instance under /files/. \
lighttpd itself comes from packagegroup-sharebox-frontend."
LICENSE = "MIT"

inherit packagegroup

# dufs-ro: read-only dufs instance (127.0.0.1:5001, no upload), provided by
# the dufs recipe (recipes-sharing/dufs).
RDEPENDS:${PN} = " \
    kiwix-serve \
    kiwix-manage \
    kiwix-tools-lighttpd \
    dufs \
    dufs-ro \
"
