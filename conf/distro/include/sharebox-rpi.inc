# Settings applied to Raspberry Pi machines when building the ShareBox distro
# (meta-raspberrypi only; ":rpi" is the SOC_FAMILY override of every Pi).

# U-Boot is the bootloader whenever updates are enabled (RAUC A/B with
# BOOT_ORDER). Without updates the Pi firmware boots the kernel directly.
RPI_USE_U_BOOT:rpi = "${@'1' if d.getVar('SHAREBOX_UPDATES') == '1' else '0'}"

# UART (see docs/deviations.md):
# U-Boot needs the UART (rpi-config refuses ENABLE_UART = "0" with U-Boot on
# the Zero W, Pi 3/4 and 64-bit boards), so it is electrically enabled
# whenever U-Boot is used, and also in the dev profile. In production no
# console and no login are attached to it: no console=serial0 on the kernel
# command line (U-Boot passes the firmware's cmdline.txt bootargs through)
# and no serial getty.
ENABLE_UART:rpi = "${@'1' if d.getVar('RPI_USE_U_BOOT') == '1' or d.getVar('SHAREBOX_DEV') == '1' else '0'}"
CMDLINE_SERIAL:rpi = "${@d.getVar('SHAREBOX_CMDLINE_SERIAL_DEV') if d.getVar('SHAREBOX_DEV') == '1' else ''}"
SHAREBOX_CMDLINE_SERIAL_DEV ?= "console=serial0,115200"
SERIAL_CONSOLES:rpi = "${@d.getVar('SHAREBOX_SERIAL_CONSOLES_DEV') if d.getVar('SHAREBOX_DEV') == '1' else ''}"
SHAREBOX_SERIAL_CONSOLES_DEV ?= "115200;ttyS0"
SHAREBOX_SERIAL_CONSOLES_DEV:raspberrypi5 ?= "115200;ttyAMA10"
SERIAL_CONSOLES_CHECK:rpi = "${SERIAL_CONSOLES}"

# Headless box: no Bluetooth, no GPU stack, no input or sound
DISABLE_VC4GRAPHICS:rpi = "1"
MACHINE_FEATURES:remove:rpi = "bluetooth vc4graphics alsa screen touchscreen keyboard"
# Smallest GPU memory split (cut-down firmware), the box has no display
GPU_MEM:rpi ?= "16"

# Wi-Fi firmware only. meta-raspberrypi already selects the right
# linux-firmware-rpidistro-bcm434xx packages per machine through
# MACHINE_EXTRA_RRECOMMENDS (bcm43430 on Zero W and Pi 3, bcm43436/bcm43436s
# on Zero 2 W, bcm43455/bcm43456 on Pi 3 B+, 4 and 5), which
# packagegroup-sharebox-base installs. Never the full linux-firmware.
# The Bluetooth firmware is dropped here.
MACHINE_EXTRA_RRECOMMENDS:remove:rpi = " \
    bluez-firmware-rpidistro-bcm43430a1-hcd \
    bluez-firmware-rpidistro-bcm43430b0-hcd \
    bluez-firmware-rpidistro-bcm4345c0-hcd \
    bluez-firmware-rpidistro-bcm4345c5-hcd \
"
