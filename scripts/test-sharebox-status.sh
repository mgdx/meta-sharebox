#!/bin/sh
# Unit tests for the /status CGI (sharebox-status.cgi) with a fake root.
set -u

TOP=$(cd "$(dirname "$0")/.." && pwd)
FILES=$TOP/recipes-core/sharebox-config/files
CGI=$FILES/sharebox-status.cgi
WORK=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT
R=$WORK/root
fail=0
pass=0

UPD=$TOP/recipes-support/sharebox-update/files

mkdir -p "$R/run/sharebox/requests" "$R/usr/share/sharebox/templates" "$R/data" \
    "$R/usr/lib/sharebox"
cp -r "$FILES/i18n" "$R/usr/share/sharebox/i18n"
# The real queuing command (its unprivileged branch: run the tests as a
# normal user)
cp "$UPD/sharebox-install-update" "$UPD/sharebox-update-lib.sh" "$R/usr/lib/sharebox/"
chmod +x "$R/usr/lib/sharebox/sharebox-install-update"
if [ "$(id -u)" = 0 ]; then
    echo "run as a normal user (sharebox-install-update would install as root)" >&2
    exit 1
fi
for d in "$FILES"/www/*/; do
    l=$(basename "$d")
    mkdir -p "$R/usr/share/sharebox/templates/$l"
    cp "$d"/status* "$R/usr/share/sharebox/templates/$l/"
done
cat > "$R/run/sharebox/env" <<'EOF'
SHAREBOX_LANG="fr"
SHAREBOX_UPDATES="1"
SHAREBOX_VERSION="1.2.3"
EOF
printf '5 GHz requires a country <b>\n' > "$R/run/sharebox/warnings"

cgi() { # cgi METHOD QUERY BODY [ACCEPT_LANGUAGE]
    printf '%s' "$3" | SHAREBOX_ROOT=$R SHAREBOX_DATA=$WORK REQUEST_METHOD=$1 QUERY_STRING=$2 \
        CONTENT_LENGTH=${#3} HTTP_ACCEPT_LANGUAGE=${4:-} sh "$CGI" > "$WORK/out"
}
check() {
    d=$1; shift
    if "$@"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $d"; fi
}
out() { grep -qF -- "$1" "$WORK/out"; }
nout() { ! grep -qF -- "$1" "$WORK/out"; }

cgi GET "" "" "de-CH,de;q=0.9"
check "header" out "Content-Type: text/html; charset=utf-8"
check "accept-language de" out 'lang="de"'
check "version" out "1.2.3"
check "warning escaped" out "<li>5 GHz requires a country &lt;b&gt;</li>"
check "no placeholder left" nout "@@"
check "no update section" nout 'name="action"'

cgi GET "lang=ja" "" "de"
check "lang param wins" out 'lang="ja"'
cgi GET "lang=../../etc" "" ""
check "path traversal ignored, SHAREBOX_LANG" out 'lang="fr"'
cgi GET "" "" "zh-TW,zh;q=0.8"
check "alias zh-TW" out 'lang="zh-Hant"'
cgi GET "" "" "pt-BR"
check "subtag fallback" out 'lang="pt"'

# --- updates (contract: docs/ARCHITECTURE.md "Updates") ---
B=/media/usb-KEY/sharebox/sharebox-1.0.raucb
cand() { # cand STATE [ERROR]: write update-candidate as the 50-rauc hook does
    printf 'state=%s\nfile=%s\nname=sharebox-1.0.raucb\nversion=1.3.0\ncurrent=1.2.3\nerror=%s\ntime=1\n' \
        "$1" "$B" "${2:-}" > "$R/run/sharebox/update-candidate"
}
cand ready
cgi GET "lang=en" "" ""
check "no section while the stick is gone" nout 'name="action"'
mkdir -p "$R/media/usb-KEY/sharebox"
: > "$R$B"
cgi GET "lang=en" "" ""
check "update section" out 'value="sharebox-1.0.raucb"'
cgi POST "" "lang=en&bundle=other.raucb&action=install" ""
check "wrong bundle refused" out "could not be installed"
check "wrong bundle message" out "has changed"
check "no request written" test ! -e "$R/run/sharebox/requests/install"
cgi POST "" "lang=en&bundle=sharebox-1.0.raucb&action=reboot" ""
check "unknown action refused" out "invalid request"
check "still no request" test ! -e "$R/run/sharebox/requests/install"
cgi POST "" "lang=en&bundle=sharebox-1.0.raucb&action=install" ""
check "install accepted" out "being installed"
check "no form after request" nout 'name="action"'
check "request queued with the candidate name" grep -qx sharebox-1.0.raucb "$R/run/sharebox/requests/install"
check "request readable by root without DAC override" \
    test "$(stat -c %a "$R/run/sharebox/requests/install")" = 644
rm -f "$R/run/sharebox/requests/install"

printf 'state=installing\nmessage=installing version 1.3.0\nversion=1.3.0\ntime=1\n' \
    > "$R/run/sharebox/update-status"
cgi GET "lang=en" "" ""
check "installing shown" out "being installed"
check "no form while installing" nout 'name="action"'
cgi POST "" "lang=en&bundle=sharebox-1.0.raucb&action=install" ""
check "no second request while installing" test ! -e "$R/run/sharebox/requests/install"

printf 'state=failed\nmessage=installation failed: signature invalid <x>\nversion=1.3.0\ntime=1\n' \
    > "$R/run/sharebox/update-status"
cgi GET "lang=en" "" ""
check "update error shown" out "signature invalid &lt;x&gt;"
check "form shown again after a failure" out 'value="sharebox-1.0.raucb"'

rm -f "$R/run/sharebox/update-status"
cand invalid "bundle for sharebox-raspberrypi5, this box is sharebox-raspberrypi4-64"
cgi GET "lang=en" "" ""
check "invalid candidate shown" out "this box is sharebox-raspberrypi4-64"
check "no form for an invalid candidate" nout 'name="action"'
cgi POST "" "lang=en&bundle=sharebox-1.0.raucb&action=install" ""
check "invalid candidate not queued" test ! -e "$R/run/sharebox/requests/install"

cand ready
sed -i 's/^SHAREBOX_UPDATES=.*/SHAREBOX_UPDATES="0"/' "$R/run/sharebox/env"
cgi GET "lang=en" "" ""
check "no form when updates are off" nout 'name="action"'

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
