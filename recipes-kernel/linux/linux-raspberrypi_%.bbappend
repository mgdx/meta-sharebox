# ShareBox kernel configuration fragments, merged by kernel-yocto on top of
# the bcm27xx defconfig (KCONFIG_MODE = "--alldefconfig").
# PCI stays enabled: the Pi 4 USB controller and the Pi 5 RP1 sit on PCIe.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://sharebox.cfg \
    file://sharebox-security.cfg \
"
