# Settings applied to Raspberry Pi machines when building the ShareBox distro
# (meta-raspberrypi only; ":rpi" is the SOC_FAMILY override of every Pi).

# U-Boot is the bootloader on every Pi (RAUC A/B with BOOT_ORDER).
RPI_USE_U_BOOT:rpi = "1"

# UART (sharebox-dev.conf sets ENABLE_UART = "1"):
# rpi-config refuses ENABLE_UART = "0" together with U-Boot on the Zero W and
# 64-bit boards (U-Boot needs the UART to operate). Production therefore
# leaves it empty: config.txt only gets "enable_uart=1" where U-Boot needs
# it, the kernel command line carries no serial console (rpi-cmdline adds
# console=serial0 only when ENABLE_UART = "1") and no getty is spawned.
ENABLE_UART:rpi = ""
SERIAL_CONSOLES:rpi = ""

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
