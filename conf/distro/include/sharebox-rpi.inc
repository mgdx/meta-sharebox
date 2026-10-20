# Settings applied to Raspberry Pi machines when building the ShareBox distro

ENABLE_UART:rpi = "${@'1' if d.getVar('SHAREBOX_DEV') == '1' else '0'}"
RPI_USE_U_BOOT:rpi = "1"
MACHINE_FEATURES:remove:rpi = "bluetooth vc4graphics"
