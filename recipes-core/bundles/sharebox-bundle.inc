# Common part of the ShareBox RAUC bundles: one signed verity bundle per
# image, containing the image's erofs root filesystem (kernel and modules
# included) for the rootfs.0 / rootfs.1 slots.
#
# A bundle recipe sets SHAREBOX_BUNDLE_ENGINE and requires this file:
#   SHAREBOX_BUNDLE_ENGINE = "modular"
#   require sharebox-bundle.inc
#
# Signing keys: development keys by default; for production set
# RAUC_KEY_FILE, RAUC_CERT_FILE and RAUC_KEYRING_FILE (absolute paths, or a
# PKCS#11 URI for the key), see files/rauc-keys/README.md.
# Derived from meta-rauc-raspberrypi recipes-core/bundles/update-bundle.bb (MIT).

SUMMARY = "ShareBox ${SHAREBOX_BUNDLE_ENGINE} update bundle"
LICENSE = "MIT"

require conf/distro/include/sharebox-storage.inc

inherit bundle

SHAREBOX_BUNDLE_IMAGE ?= "sharebox-image-${SHAREBOX_BUNDLE_ENGINE}"

RAUC_BUNDLE_COMPATIBLE = "${SHAREBOX_RAUC_COMPATIBLE}"
RAUC_BUNDLE_VERSION = "${DISTRO_VERSION}"
RAUC_BUNDLE_DESCRIPTION = "${DISTRO_NAME} ${DISTRO_VERSION} (${SHAREBOX_BUNDLE_ENGINE})"
RAUC_BUNDLE_FORMAT = "verity"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "${SHAREBOX_BUNDLE_IMAGE}"
RAUC_SLOT_rootfs[fstype] = "erofs"
# RAUC has no erofs image type: the slot is written as a raw image
RAUC_SLOT_rootfs[imagetype] = "raw"

SHAREBOX_RAUC_DEV_KEYS := "${@os.path.normpath(os.path.join(d.getVar('THISDIR'), '../../files/rauc-keys/dev'))}"
RAUC_KEY_FILE ?= "${SHAREBOX_RAUC_DEV_KEYS}/development-1.key.pem"
RAUC_CERT_FILE ?= "${SHAREBOX_RAUC_DEV_KEYS}/development-1.cert.pem"
RAUC_KEYRING_FILE ?= "${SHAREBOX_RAUC_DEV_KEYS}/ca.cert.pem"

python () {
    if d.getVar('SHAREBOX_UPDATES') != '1':
        raise bb.parse.SkipRecipe("RAUC updates are disabled (SHAREBOX_UPDATES != \"1\")")
}

python sharebox_bundle_check_keys () {
    keydir = d.getVar('SHAREBOX_RAUC_DEV_KEYS')
    key = d.getVar('RAUC_KEY_FILE') or ''
    if key.startswith(keydir + '/') and d.getVar('SHAREBOX_DEV') != '1':
        bb.warn("%s is signed with the public ShareBox development key: any box "
                "built with the development keyring will accept bundles from anybody. "
                "Set RAUC_KEY_FILE, RAUC_CERT_FILE and RAUC_KEYRING_FILE for production "
                "(files/rauc-keys/README.md)." % d.getVar('PN'))
}
do_bundle[prefuncs] += "sharebox_bundle_check_keys"
