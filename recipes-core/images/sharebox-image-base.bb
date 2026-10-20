SUMMARY = "ShareBox base image: network, captive portal and home page only"
DESCRIPTION = "Common ShareBox system without any sharing engine, used to \
validate the access point, DHCP/DNS, captive portal and firewall, and to \
measure the footprint of the base system."
LICENSE = "MIT"

SHAREBOX_ENGINE = "base"

inherit sharebox-image

IMAGE_INSTALL += "packagegroup-sharebox-frontend"
