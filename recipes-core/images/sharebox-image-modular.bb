SUMMARY = "ShareBox image with the modular engine (lighttpd, dufs, Ergo, gamja)"
LICENSE = "MIT"

SHAREBOX_ENGINE = "modular"
inherit sharebox-image

IMAGE_INSTALL += "packagegroup-sharebox-frontend packagegroup-sharebox-engine-modular"
