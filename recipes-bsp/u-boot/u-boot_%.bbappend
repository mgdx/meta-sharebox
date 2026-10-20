# erofs support for the A/B boot script (kernel inside the rootfs slot), and
# no autoboot interruption in production.
require conf/distro/include/sharebox-storage.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:rpi = "${@' file://sharebox-erofs.cfg' if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"
SRC_URI:append:rpi = "${@' file://sharebox-nodelay.cfg' if d.getVar('SHAREBOX_DEV') != '1' else ''}"
