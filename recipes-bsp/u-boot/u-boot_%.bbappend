# erofs support for the A/B boot script (kernel inside the rootfs slot)
require conf/distro/include/sharebox-storage.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:rpi = "${@' file://sharebox-erofs.cfg' if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"
