# Core distro features shared by all ShareBox images

INIT_MANAGER = "systemd"
TCLIBC = "glibc"

DISTRO_FEATURES = "wifi systemd usrmerge ipv4 ipv6 seccomp acl xattr largefile pam"
DISTRO_FEATURES:append = "${@' rauc' if d.getVar('SHAREBOX_UPDATES') == '1' else ''}"
DISTRO_FEATURES:remove = "x11 wayland opengl vulkan bluetooth alsa pulseaudio nfs zeroconf ptest 3g nfc"
DISTRO_FEATURES_OPTED_OUT += "pulseaudio gobject-introspection-data"

# journald only, no syslog daemon
VIRTUAL-RUNTIME_syslog = ""
VIRTUAL-RUNTIME_base-utils-syslog = ""

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
