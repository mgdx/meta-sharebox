SUMMARY = "ShareBox image with the library engine (Kiwix + read-only dufs)"
DESCRIPTION = "LibraryBox-style image: offline encyclopedias and other ZIM \
content served by kiwix-serve under /wiki/, read-only file share under \
/files/, no upload and no chat. Targets Raspberry Pi 3, 4 and 5 (Zero 2 W \
with small ZIM files only)."
LICENSE = "MIT"

SHAREBOX_ENGINE = "library"

inherit sharebox-image

IMAGE_INSTALL += " \
    packagegroup-sharebox-frontend \
    packagegroup-sharebox-engine-library \
"
