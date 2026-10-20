SUMMARY = "ShareBox image with every engine (modular + library)"
DESCRIPTION = "Everything behind lighttpd: dufs file share with anonymous \
upload, Ergo IRC chat with the gamja web client, the forum, Kiwix offline \
library and a read-only dufs instance. Reserved for Raspberry Pi 4 and 5 \
(2 GB of RAM or more)."
LICENSE = "MIT"

SHAREBOX_ENGINE = "full"

# Forum (Sriracha) is part of the full image. SHAREBOX_FORUM is the switch of
# the modular engine (home page, lighttpd /forum/). A variable set here is not
# seen by the packagegroup recipes, so the forum packages are installed
# explicitly by the image.
SHAREBOX_FORUM = "1"
SHAREBOX_FORUM_PACKAGES ?= "sriracha sriracha-lighttpd"

# Optional DLNA/UPnP media server (meta-multimedia minidlna), off by default.
# It serves /data/share to DLNA clients; its ports (tcp/8200, udp/1900) must
# also be opened in the firewall to be useful.
SHAREBOX_DLNA ?= "0"

inherit sharebox-image

COMPATIBLE_MACHINE = "^(raspberrypi4-64|raspberrypi5|raspberrypi-armv8)$"

IMAGE_INSTALL += " \
    packagegroup-sharebox-frontend \
    packagegroup-sharebox-engine-modular \
    packagegroup-sharebox-engine-library \
    ${@d.getVar('SHAREBOX_FORUM_PACKAGES') if d.getVar('SHAREBOX_FORUM') == '1' else ''} \
    ${@'minidlna' if d.getVar('SHAREBOX_DLNA') == '1' else ''} \
"

python () {
    if d.getVar('SHAREBOX_DLNA') == '1' and \
            'multimedia-layer' not in (d.getVar('BBFILE_COLLECTIONS') or '').split():
        bb.fatal("SHAREBOX_DLNA = \"1\" needs meta-multimedia (minidlna) in bblayers.conf")
}
