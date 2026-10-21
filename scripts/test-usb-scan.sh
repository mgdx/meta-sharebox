#!/bin/sh
# Unit tests for sharebox-usb-scan with a fake root.
set -u
TOP=$(cd "$(dirname "$0")/.." && pwd)
SCAN=$TOP/recipes-support/usb-automount/files/sharebox-usb-scan
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
R=$WORK/root
fail=0
pass=0
check() {
    d=$1; shift
    if "$@"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $d"; fi
}
run() {
    SHAREBOX_ROOT=$R SHAREBOX_MOUNTS=$WORK/mounts SHAREBOX_NO_SYSTEMCTL=1 sh "$SCAN" 2> "$WORK/log"
}

mkdir -p "$R/media" "$R/data/share" "$R/data/config" "$R/usr/lib/sharebox/usb-hooks.d"
cat > "$R/usr/lib/sharebox/usb-hooks.d/10-test" <<EOF
#!/bin/sh
echo "\$#:\$*" > "$WORK/hook"
EOF
chmod +x "$R/usr/lib/sharebox/usb-hooks.d/10-test"

# No stick
: > "$WORK/mounts"
run
check "no link without stick" test ! -e "$R/data/share/usb"
check "hook called without args" grep -qx "0:" "$WORK/hook"

# One stick with share/ and a configuration
mkdir -p "$R/media/usb-KEY/share" "$R/media/usb-KEY/sharebox"
printf 'country=FR\n' > "$R/media/usb-KEY/sharebox/sharebox.conf"
echo "systemd-1 /media/usb-KEY autofs rw 0 0" > "$WORK/mounts"
run
check "link to share/" test "$(readlink "$R/data/share/usb")" = /media/usb-KEY/share
check "config copied" grep -qx country=FR "$R/data/config/sharebox.conf"
check "restart logged" grep -q "restarting the access point" "$WORK/log"
check "hook called with mount" grep -qx "1:$R/media/usb-KEY" "$WORK/hook"

# Same again: no copy
run
check "no copy when identical" sh -c "! grep -q restarting $WORK/log"

# Stick removed (mount point left behind, not mounted any more)
: > "$WORK/mounts"
run
check "link removed" test ! -e "$R/data/share/usb"

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
