SUMMARY = "ShareBox image with the shareboxx engine (ShareBoxx)"
DESCRIPTION = "Single Rust binary with a modern web interface: ShareBoxx \
alone serves port 80. For the Pi Zero 2 W, 3, 4 and 5 (64-bit)."
LICENSE = "MIT"

SHAREBOX_ENGINE = "shareboxx"
inherit sharebox-image

IMAGE_INSTALL += "packagegroup-sharebox-engine-shareboxx"

# ShareBoxx is built for 64-bit machines only (spec: Zero 2 W, 3, 4, 5).
COMPATIBLE_MACHINE = "^(raspberrypi0-2w-64|raspberrypi3-64|raspberrypi4-64|raspberrypi5|raspberrypi-armv8)$"
