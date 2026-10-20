SUMMARY = "ShareBox image with the classic engine (luffy)"
DESCRIPTION = "PirateBox spirit: luffy alone serves port 80. Suitable for \
every supported Raspberry Pi, including the Pi Zero W."
LICENSE = "MIT"

SHAREBOX_ENGINE = "classic"
inherit sharebox-image

IMAGE_INSTALL += "packagegroup-sharebox-engine-classic"
