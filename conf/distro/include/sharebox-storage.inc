# ShareBox storage layout, shared by every recipe that needs to know it:
# sharebox-storage.bbclass (wks, fstab, /etc and /var overlays), rpi-cmdline
# (root= in cmdline.txt), rpi-u-boot-scr (A/B boot script), rauc-conf
# (system.conf slots) and sharebox-storage (data partition growth).
#
# Required with `require conf/distro/include/sharebox-storage.inc` by those
# files; it only uses weak assignments and can be included several times.
#
# Partition layout (msdos label, see wic/sharebox-{dual,single}.wks.in):
#
#   SHAREBOX_UPDATES = "1"            SHAREBOX_UPDATES = "0"
#   p1 boot     vfat   128M           p1 boot    vfat   128M
#   p2 rootfs A erofs  512M           p2 rootfs  erofs  512M
#   p3 rootfs B erofs  512M           p3 data    ext4   rest of the card
#   p4 data     ext4   rest of the card

SHAREBOX_UPDATES ??= "1"
SHAREBOX_DATA_FS ??= "ext4"

# Disk the box boots from, as seen by Linux, and its partition device prefix.
SHAREBOX_DISK ??= "mmcblk0"
SHAREBOX_PART_PREFIX ??= "/dev/${SHAREBOX_DISK}p"
# Same disk as seen by U-Boot ("<interface> <device>")
SHAREBOX_UBOOT_DISK ??= "mmc 0"

SHAREBOX_BOOT_PARTNUM = "1"
SHAREBOX_ROOT_A_PARTNUM = "2"
SHAREBOX_ROOT_B_PARTNUM = "3"
SHAREBOX_DATA_PARTNUM = "${@'4' if d.getVar('SHAREBOX_UPDATES') == '1' else '3'}"

SHAREBOX_BOOT_DEVICE = "${SHAREBOX_PART_PREFIX}${SHAREBOX_BOOT_PARTNUM}"
SHAREBOX_ROOT_A_DEVICE = "${SHAREBOX_PART_PREFIX}${SHAREBOX_ROOT_A_PARTNUM}"
SHAREBOX_ROOT_B_DEVICE = "${SHAREBOX_PART_PREFIX}${SHAREBOX_ROOT_B_PARTNUM}"
SHAREBOX_DATA_DEVICE = "${SHAREBOX_PART_PREFIX}${SHAREBOX_DATA_PARTNUM}"

# Mount options of /data. commit=5 bounds the data lost on a power cut to
# about five seconds; barriers stay enabled (never add nobarrier).
SHAREBOX_DATA_MOUNT_OPTIONS ??= "noatime,nodev,nosuid${@',commit=5' if d.getVar('SHAREBOX_DATA_FS') in ('ext3', 'ext4') else ''}"

# RAUC compatible string, shared by system.conf and the bundles
SHAREBOX_RAUC_COMPATIBLE ??= "sharebox-${MACHINE}"
