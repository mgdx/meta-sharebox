# ShareBox: the box is offline, bundles come from USB sticks only.
# - no HTTP(S) streaming or network download (drops curl, libnl, nbd use)
# - no GPT boot partition switching, no JSON output (drops json-glib)
PACKAGECONFIG:remove = "network streaming gpt json"

# The uboot backend runs fw_setenv/fw_printenv (u-boot-fw-utils, from
# libubootenv), which read /etc/fw_env.config, shipped in u-boot-env by
# meta-raspberrypi. meta-rauc only adds u-boot-fw-utils when
# PREFERRED_PROVIDER_virtual/bootloader is set, which meta-raspberrypi does not.
RDEPENDS:${PN}:append:rpi = " u-boot-fw-utils u-boot-env"
