# Read-only erofs root filesystem (see classes/sharebox-storage.bbclass).
# With A/B updates, root= is not in cmdline.txt: the U-Boot script appends
# root=<slot> and rauc.slot=<A|B> for the slot it selected.
require conf/distro/include/sharebox-storage.inc

CMDLINE_ROOT_FSTYPE = "rootfstype=erofs ro"
CMDLINE_ROOT_PARTITION = "${SHAREBOX_ROOT_A_DEVICE}"
CMDLINE_ROOTFS = "${@'' if d.getVar('SHAREBOX_UPDATES') == '1' else 'root=${CMDLINE_ROOT_PARTITION} '}${CMDLINE_ROOT_FSTYPE} rootwait"

# Reboot 10 s after a kernel panic, so that a slot that does not boot uses
# up its U-Boot attempts and the previous slot is selected.
CMDLINE:append = " panic=10"
