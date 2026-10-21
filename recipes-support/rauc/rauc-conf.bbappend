# ShareBox RAUC system.conf and keyring (CA certificate).
#
# Development keyring by default; for production set RAUC_KEYRING_FILE (an
# absolute path) in local.conf or kas, see files/rauc-keys/README.md.
require conf/distro/include/sharebox-storage.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SHAREBOX_RAUC_DEV_KEYS := "${@os.path.normpath(os.path.join(d.getVar('THISDIR'), '../../files/rauc-keys/dev'))}"
RAUC_KEYRING_FILE ?= "${SHAREBOX_RAUC_DEV_KEYS}/ca.cert.pem"

do_install:append() {
    keyring=$(basename "${RAUC_KEYRING_FILE}")
    sed -i \
        -e "s#@@COMPATIBLE@@#${SHAREBOX_RAUC_COMPATIBLE}#" \
        -e "s#@@KEYRING@@#$keyring#" \
        -e "s#@@ROOT_A_DEVICE@@#${SHAREBOX_ROOT_A_DEVICE}#" \
        -e "s#@@ROOT_B_DEVICE@@#${SHAREBOX_ROOT_B_DEVICE}#" \
        ${D}${nonarch_libdir}/rauc/system.conf
    if grep -q '@@[A-Z_]*@@' ${D}${nonarch_libdir}/rauc/system.conf; then
        bbfatal "unsubstituted token in system.conf"
    fi
    if ! grep -q "BEGIN CERTIFICATE" ${D}${nonarch_libdir}/rauc/$keyring; then
        bbfatal "RAUC keyring ${RAUC_KEYRING_FILE} does not contain a PEM certificate"
    fi
    if grep -q "PRIVATE KEY" ${D}${nonarch_libdir}/rauc/$keyring; then
        bbfatal "RAUC keyring ${RAUC_KEYRING_FILE} contains a private key"
    fi
}
