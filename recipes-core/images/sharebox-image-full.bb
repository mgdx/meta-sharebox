SUMMARY = "ShareBox image with every engine (modular + library)"
DESCRIPTION = "Everything behind lighttpd: dufs file share with anonymous \
upload, Ergo IRC chat with the gamja web client, Kiwix offline library \
and a read-only dufs instance. Reserved for Raspberry Pi 4 and 5 \
(2 GB of RAM or more)."
LICENSE = "MIT"

SHAREBOX_ENGINE = "full"

# No forum: Sriracha was dropped (see docs/deviations.md, "Modular engine").

# In the full image /files/ is the read-only dufs instance (5001) and
# /upload/ the writable one (5000), so the modular /files/ snippet is dropped.
BAD_RECOMMENDATIONS += "dufs-lighttpd"

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
    dufs-upload-lighttpd \
    ${@'minidlna' if d.getVar('SHAREBOX_DLNA') == '1' else ''} \
"

python () {
    if d.getVar('SHAREBOX_DLNA') == '1' and \
            'multimedia-layer' not in (d.getVar('BBFILE_COLLECTIONS') or '').split():
        bb.fatal("SHAREBOX_DLNA = \"1\" needs meta-multimedia (minidlna) in bblayers.conf")
}
