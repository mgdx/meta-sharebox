# ShareBox: the box is offline, bundles come from USB sticks only.
# - no HTTP(S) streaming or network download (drops curl, libnl, nbd use)
# - no GPT boot partition switching, no JSON output (drops json-glib)
PACKAGECONFIG:remove = "network streaming gpt json"

# fw_setenv/fw_printenv (u-boot-fw-utils, added by meta-rauc) need
# /etc/fw_env.config, shipped in u-boot-env by meta-raspberrypi.
RDEPENDS:${PN}:append:rpi = " u-boot-env"
