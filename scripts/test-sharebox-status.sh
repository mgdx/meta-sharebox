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

mkdir -p "$R/run/sharebox/requests" "$R/usr/share/sharebox/templates" "$R/data"
cp -r "$FILES/i18n" "$R/usr/share/sharebox/i18n"
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

printf '/media/usb-KEY/sharebox/sharebox-1.0.raucb\n' > "$R/run/sharebox/update-bundle"
cgi GET "lang=en" "" ""
check "update section" out 'value="sharebox-1.0.raucb"'
cgi POST "" "lang=en&bundle=other.raucb&action=install" ""
check "wrong bundle refused" out "could not be installed"
check "no request written" test ! -e "$R/run/sharebox/requests/install"
cgi POST "" "lang=en&bundle=sharebox-1.0.raucb&action=install" ""
check "install accepted" out "being installed"
check "request written" grep -qx /media/usb-KEY/sharebox/sharebox-1.0.raucb "$R/run/sharebox/requests/install"
rm -f "$R/run/sharebox/update-bundle"
printf 'error: signature invalid <x>\n' > "$R/run/sharebox/update-result"
cgi GET "lang=en" "" ""
check "update error shown" out "signature invalid &lt;x&gt;"

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
