# Storage/update kernel options (erofs root, overlays, RAUC verity bundles).
# Owned by the storage lot; other kernel fragments go next to it.
FILESEXTRAPATHS:prepend := "${THISDIR}/sharebox-storage:"
SRC_URI:append = " file://sharebox-storage.cfg"
