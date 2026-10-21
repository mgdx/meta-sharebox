# Core distro features shared by all ShareBox images

INIT_MANAGER = "systemd"
TCLIBC = "glibc"

DISTRO_FEATURES = "wifi systemd usrmerge ipv4 ipv6 seccomp acl xattr largefile pam"
DISTRO_FEATURES:append = "${@' rauc' if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"
# meta-rauc stays in the layer list when updates are off: do not warn then
SKIP_META_RAUC_FEATURE_CHECK = "${@'0' if d.getVar('SHAREBOX_UPDATES') == '1' else '1'}"
DISTRO_FEATURES:remove = "x11 wayland opengl vulkan bluetooth alsa pulseaudio nfs zeroconf ptest 3g nfc"
DISTRO_FEATURES_OPTED_OUT += "pulseaudio gobject-introspection-data"

# journald only, no syslog daemon
VIRTUAL-RUNTIME_syslog = ""
VIRTUAL-RUNTIME_base-utils-syslog = ""

# No locales on target: pages are static, translated per directory
IMAGE_LINGUAS = ""

# ShareBox tunables (override in local.conf or kas)
SHAREBOX_SSID ??= ""
SHAREBOX_LANG ??= ""
SHAREBOX_IPV4 ??= "192.168.77.1/24"
SHAREBOX_HOSTNAME ??= "sharebox.lan"
SHAREBOX_CHANNEL ??= "6"
SHAREBOX_5GHZ ??= "0"
SHAREBOX_COUNTRY ??= ""
SHAREBOX_DATA_FS ??= "ext4"
SHAREBOX_UPLOAD_MAX ??= "2G"
SHAREBOX_CAPTIVE_MODE ??= "popup"
SHAREBOX_UPDATES ??= "1"
SHAREBOX_VERITY ??= "0"
SHAREBOX_DEV ??= "0"

# Short host name ("sharebox" for "sharebox.lan"), written to /etc/hostname
hostname:pn-base-files = "${@d.getVar('SHAREBOX_HOSTNAME').split('.')[0]}"
