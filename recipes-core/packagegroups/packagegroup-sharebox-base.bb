SUMMARY = "ShareBox base system"
DESCRIPTION = "Packages common to every ShareBox image: access point, \
DHCP/DNS, firewall, runtime configuration, USB sticks, Wi-Fi firmware and \
updates."
LICENSE = "MIT"

# MACHINE_EXTRA_RRECOMMENDS (Wi-Fi firmware, kernel modules) is machine specific
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SHAREBOX_UPDATES ??= "1"

RDEPENDS:${PN} = " \
    os-release \
    systemd \
    systemd-networkd \
    hostapd \
    dnsmasq \
    nftables \
    sharebox-config \
    usb-automount \
    wireless-regdb-static \
    ${@'rauc sharebox-update sharebox-healthcheck' if d.getVar('SHAREBOX_UPDATES') == '1' else ''} \
"

# sharebox-storage and, with updates, kernel-image are added to the image by
# sharebox-storage.bbclass, not here.

# Wi-Fi firmware selected by meta-raspberrypi per machine (Bluetooth
# firmware removed in sharebox-rpi.inc), kernel modules, rpi udev rules.
RRECOMMENDS:${PN} = " \
    ${MACHINE_EXTRA_RRECOMMENDS} \
"
