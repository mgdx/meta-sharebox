# ShareBox storage: read-only erofs root filesystem, persistent /data
# partition, /etc and /var as overlays on /data, and the wic layout (A/B slots
# when SHAREBOX_UPDATES = "1", a single slot otherwise).
#
# Inherited by sharebox-image.bbclass; do not inherit it from a recipe that
# is not an image. See docs/updates.md and docs/ARCHITECTURE.md ("Storage").
#
# Boot flow
#   firmware -> U-Boot -> boot.scr -> kernel (root=<slot>, rootfstype=erofs, ro)
#   -> /sbin/init = sharebox preinit (fsck + mount /data, /etc and /var
#   overlays) -> systemd (/sbin/init.orig)
#
# With updates, the kernel is read by U-Boot from /boot of the selected erofs
# slot, so a bundle updates kernel, modules and userspace together. The boot
# partition (firmware, config.txt, cmdline.txt, device trees, U-Boot,
# boot.scr) is static. Without updates, the stock meta-raspberrypi layout is
# kept: the kernel stays on the boot partition.

require conf/distro/include/sharebox-storage.inc

SHAREBOX_BOOT_SIZE ??= "128M"
SHAREBOX_ROOTFS_SIZE ??= "512M"
# Initial size of the data partition; it is grown to the end of the card at
# first boot by sharebox-grow-data.service.
SHAREBOX_DATA_SIZE ??= "256M"

# erofs, lz4hc compressed (decompressed with plain lz4 by Linux and U-Boot)
SHAREBOX_EROFS_OPTS ??= "-zlz4hc"
EXTRA_IMAGECMD:erofs = "${SHAREBOX_EROFS_OPTS}"

SHAREBOX_IMAGE_FSTYPES ??= "erofs wic.gz wic.bmap"
IMAGE_FSTYPES = "${SHAREBOX_IMAGE_FSTYPES}"
# The wic image copies the erofs image into the rootfs slot(s) (rawcopy), so
# that the slot written at flash time is byte-identical to the bundle payload.
IMAGE_TYPEDEP:wic:append = " erofs"

WKS_FILE = "${@'sharebox-dual.wks.in' if d.getVar('SHAREBOX_UPDATES') == '1' else 'sharebox-single.wks.in'}"
WKS_SEARCH_PATH:prepend = "${@''.join('%s/wic:' % p for p in d.getVar('BBPATH').split(':') if p)}"

# Read-only root, /etc overlay set up by our own preinit template
IMAGE_FEATURES:append = " read-only-rootfs overlayfs-etc"
OVERLAYFS_ETC_MOUNT_POINT = "/data"
OVERLAYFS_ETC_FSTYPE = "${SHAREBOX_DATA_FS}"
OVERLAYFS_ETC_DEVICE = "${SHAREBOX_DATA_DEVICE}"
OVERLAYFS_ETC_MOUNT_OPTIONS = "${SHAREBOX_DATA_MOUNT_OPTIONS}"
OVERLAYFS_ETC_CREATE_MOUNT_DIRS = "0"
OVERLAYFS_ETC_EXPOSE_LOWER = "0"
OVERLAYFS_ETC_INIT_TEMPLATE = "${@bb.utils.which(d.getVar('BBPATH'), 'files/storage/sharebox-preinit.sh.in')}"

# fsck helper config, data partition growth
IMAGE_INSTALL:append = " sharebox-storage"

# With A/B updates the kernel lives in the rootfs slot, not on the boot
# partition. The update packages themselves (rauc, sharebox-update,
# sharebox-healthcheck) are pulled in by packagegroup-sharebox-base.
IMAGE_INSTALL:append = "${@' kernel-image' if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"
RPI_EXTRA_IMAGE_BOOT_FILES:remove = "${@d.getVar('KERNEL_IMAGETYPE') if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"

# sharebox-healthcheck marks the slot good, not rauc-mark-good (which only
# waits for boot-complete.target)
BAD_RECOMMENDATIONS += "rauc-mark-good"

ROOTFS_POSTPROCESS_COMMAND += "sharebox_storage_rootfs; "

sharebox_storage_rootfs () {
	# Mount points must exist in the read-only image
	install -d -m 0755 ${IMAGE_ROOTFS}/data ${IMAGE_ROOTFS}/boot

	# /data is mounted by the preinit (with fsck); the fstab entry lets
	# systemd know about it for RequiresMountsFor=/data.
	printf '%s\t/data\t%s\t%s\t0\t0\n' \
		"${SHAREBOX_DATA_DEVICE}" "${SHAREBOX_DATA_FS}" "${SHAREBOX_DATA_MOUNT_OPTIONS}" \
		>> ${IMAGE_ROOTFS}${sysconfdir}/fstab

	if [ "${SHAREBOX_UPDATES}" = "1" ]; then
		# The boot partition holds the U-Boot environment (BOOT_ORDER,
		# BOOT_x_LEFT) written by fw_setenv (/etc/fw_env.config).
		printf '%s\t/boot\tvfat\tnoatime,nodev,nosuid,noexec,umask=0077\t0\t0\n' \
			"${SHAREBOX_BOOT_DEVICE}" >> ${IMAGE_ROOTFS}${sysconfdir}/fstab

		# U-Boot loads /boot/${KERNEL_IMAGETYPE} from the erofs slot: make it a
		# regular file rather than a symlink to the versioned image.
		img=${IMAGE_ROOTFS}/boot/${KERNEL_IMAGETYPE}
		if [ -L "$img" ]; then
			target=$(readlink "$img")
			case "$target" in
			/*) target=${IMAGE_ROOTFS}$target ;;
			*) target=${IMAGE_ROOTFS}/boot/$target ;;
			esac
			rm -f "$img"
			mv "$target" "$img"
		fi
		if [ ! -f "$img" ]; then
			bbfatal "sharebox-storage: /boot/${KERNEL_IMAGETYPE} missing from the rootfs, U-Boot could not boot it"
		fi
	fi
}
sharebox_storage_rootfs[vardeps] += "SHAREBOX_UPDATES SHAREBOX_DATA_DEVICE SHAREBOX_DATA_FS SHAREBOX_DATA_MOUNT_OPTIONS SHAREBOX_BOOT_DEVICE"

python () {
    fs = d.getVar('SHAREBOX_DATA_FS')
    # wic must be able to create it empty, the preinit checks it with e2fsck
    # and sharebox-grow-data grows it online with resize2fs.
    if fs not in ('ext4', 'ext3', 'ext2'):
        bb.fatal("SHAREBOX_DATA_FS = '%s' is not supported (ext4, ext3, ext2)" % fs)
    if not d.getVar('OVERLAYFS_ETC_INIT_TEMPLATE'):
        bb.fatal("sharebox-storage: files/storage/sharebox-preinit.sh.in not found in BBPATH")
}
