# Common logic of every ShareBox image.
#
# An image recipe sets SHAREBOX_ENGINE, inherits this class and appends its
# engine packagegroups to IMAGE_INSTALL:
#
#   SHAREBOX_ENGINE = "modular"
#   inherit sharebox-image
#   IMAGE_INSTALL += "packagegroup-sharebox-frontend packagegroup-sharebox-engine-modular"
#
# The storage layout (erofs, overlayfs-etc, wks, IMAGE_FSTYPES, RAUC bundle
# hooks) lives in sharebox-storage.bbclass.

SHAREBOX_ENGINE ??= "base"
SHAREBOX_ENGINES = "base classic modular shareboxx library full"

LICENSE ?= "MIT"

inherit core-image

# Read-only rootfs, no package manager, no locales
IMAGE_FEATURES += "read-only-rootfs"
IMAGE_LINGUAS = ""

# The whole image content is explicit: no packagegroup-base-extended
IMAGE_INSTALL = " \
    packagegroup-core-boot \
    packagegroup-sharebox-base \
    sharebox-config-${SHAREBOX_ENGINE} \
    ${@'sharebox-config-devaccess' if d.getVar('SHAREBOX_DEV') == '1' else ''} \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"

inherit sharebox-storage

python () {
    engine = d.getVar('SHAREBOX_ENGINE')
    if engine not in d.getVar('SHAREBOX_ENGINES').split():
        bb.fatal("SHAREBOX_ENGINE = '%s' is not one of: %s" % (engine, d.getVar('SHAREBOX_ENGINES')))
}

# Fail the build when an interpreter slipped into the image through a
# runtime dependency (python3*, perl*, php*, nodejs* by default).
python sharebox_check_forbidden_packages () {
    from oe.rootfs import image_list_installed_packages

    prefixes = tuple((d.getVar('SHAREBOX_FORBIDDEN_PACKAGES') or '').split())
    if not prefixes:
        return
    installed = image_list_installed_packages(d)
    bad = sorted(p for p in installed if p.startswith(prefixes))
    if bad:
        bb.fatal("ShareBox images must not contain interpreters, found: %s. "
                 "Find the culprit with 'oe-pkgdata-util' or the image "
                 "manifest and drop the dependency." % " ".join(bad))
}
ROOTFS_POSTPROCESS_COMMAND += "sharebox_check_forbidden_packages"

# Development profile: dropbear accepts public keys only. The firewall
# (sharebox-config-dev) only opens port 22 on interfaces other than wlan0.
sharebox_dropbear_keys_only () {
    f=${IMAGE_ROOTFS}${sysconfdir}/default/dropbear
    if [ -e ${IMAGE_ROOTFS}${sbindir}/dropbear ]; then
        if grep -q '^DROPBEAR_EXTRA_ARGS=' $f 2>/dev/null; then
            sed -i -e '/^DROPBEAR_EXTRA_ARGS=/ s/ *-B//g' \
                   -e 's/^DROPBEAR_EXTRA_ARGS="*\([^"]*\)"*/DROPBEAR_EXTRA_ARGS="\1 -s"/' $f
        else
            printf '\n# ShareBox dev: public key authentication only\nDROPBEAR_EXTRA_ARGS="-s"\n' >> $f
        fi
    fi
}
ROOTFS_POSTPROCESS_COMMAND += "${@'sharebox_dropbear_keys_only' if d.getVar('SHAREBOX_DEV') == '1' else ''}"
