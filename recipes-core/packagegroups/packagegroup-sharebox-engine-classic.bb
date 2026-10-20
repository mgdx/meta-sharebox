SUMMARY = "ShareBox 'classic' engine: luffy (PirateBox compatible)"
DESCRIPTION = "luffy serves files, droopy style uploads, the shoutbox chat \
and the forum on port 80 by itself; lighttpd is not installed."
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = "luffy"
