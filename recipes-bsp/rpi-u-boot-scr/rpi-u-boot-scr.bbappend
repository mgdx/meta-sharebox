# A/B boot script when RAUC updates are enabled (SHAREBOX_UPDATES = "1").
# Without updates the stock meta-raspberrypi script (kernel on the boot
# partition) is kept.
require conf/distro/include/sharebox-storage.inc

SHAREBOX_UBOOT_SCR_DIR := "${THISDIR}/files"
FILESEXTRAPATHS:prepend = "${@'${SHAREBOX_UBOOT_SCR_DIR}:' if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"

do_compile() {
    sed -e 's/@@KERNEL_IMAGETYPE@@/${KERNEL_IMAGETYPE}/' \
        -e 's/@@KERNEL_BOOTCMD@@/${KERNEL_BOOTCMD}/' \
        -e 's/@@BOOT_MEDIA@@/${BOOT_MEDIA}/' \
        -e 's#@@ROOT_A_DEVICE@@#${SHAREBOX_ROOT_A_DEVICE}#' \
        -e 's#@@ROOT_B_DEVICE@@#${SHAREBOX_ROOT_B_DEVICE}#' \
        -e 's#@@ROOT_A_PARTNUM@@#${SHAREBOX_ROOT_A_PARTNUM}#' \
        -e 's#@@ROOT_B_PARTNUM@@#${SHAREBOX_ROOT_B_PARTNUM}#' \
        -e 's#@@UBOOT_DISK@@#${SHAREBOX_UBOOT_DISK}#' \
        "${UNPACKDIR}/boot.cmd.in" > "${WORKDIR}/boot.cmd"
    if grep -q '@@[A-Z_]*@@' "${WORKDIR}/boot.cmd"; then
        bbfatal "unsubstituted token in boot.cmd: $(grep -o '@@[A-Z_]*@@' ${WORKDIR}/boot.cmd | sort -u | tr '\n' ' ')"
    fi
    mkimage -A ${UBOOT_ARCH} -T script -C none -n "Boot script" -d "${WORKDIR}/boot.cmd" boot.scr
}
do_compile[vardeps] += "SHAREBOX_UPDATES"
