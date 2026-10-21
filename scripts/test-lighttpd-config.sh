#!/bin/sh
# Integration test of the lighttpd configuration (main config, runtime file
# from sharebox-setup, captive portal, language negotiation, /status) with a
# host build of lighttpd 1.4.8x (mod_cgi, mod_proxy, mod_webdav built).
#
# Usage: scripts/test-lighttpd-config.sh /path/to/lighttpd-prefix
#   (directory with sbin/lighttpd and lib/lighttpd/mod_*.so)
set -u
PREFIX=${1:?usage: $0 <lighttpd install prefix>}
LIGHTTPD=$PREFIX/sbin/lighttpd
TOP=$(cd "$(dirname "$0")/.." && pwd)
FILES=$TOP/recipes-core/sharebox-config/files
PORT=${PORT:-18080}
WORK=$(mktemp -d)
R=$WORK/root
fail=0
pass=0
pid=""
cleanup() { [ -n "$pid" ] && kill "$pid" 2>/dev/null; [ -n "${KEEP:-}" ] || rm -rf "$WORK"; }
trap cleanup EXIT

# --- fake root ---------------------------------------------------------------
mkdir -p "$R/usr/lib/sharebox/cgi-bin" "$R/usr/share/sharebox/www" "$R/usr/share/sharebox/templates" \
         "$R/etc/lighttpd/conf.d" "$R/usr/share/captive-portal" "$R/run/sharebox/requests" "$R/data/config" "$R/data/share"
cp -r "$FILES/i18n" "$R/usr/share/sharebox/i18n"
cp "$FILES/www/style.css" "$R/usr/share/sharebox/www/"
for d in "$FILES"/www/*/; do
    l=$(basename "$d")
    mkdir -p "$R/usr/share/sharebox/www/$l" "$R/usr/share/sharebox/templates/$l"
    cp "$d"/how-it-works.html "$R/usr/share/sharebox/www/$l/"
    cp "$d"/status* "$R/usr/share/sharebox/templates/$l/"
    sed -e "/@@ENGINE_LINKS@@/r $d/engine-base.html" -e '/@@ENGINE_LINKS@@/d' "$d/index.html.in" \
        > "$R/usr/share/sharebox/www/$l/index.html"
done
cp "$FILES/sharebox-status.cgi" "$R/usr/lib/sharebox/cgi-bin/status"
chmod 755 "$R/usr/lib/sharebox/cgi-bin/status"
CP=$TOP/recipes-connectivity/captive-portal/files
cp "$CP/popup.conf" "$CP/silent.conf" "$R/usr/share/captive-portal/"
cp -r "$CP/probes" "$R/usr/share/captive-portal/probes"
chmod 755 "$R/usr/share/captive-portal/probes/204.cgi"
sed -e "s#/run/sharebox#$R/run/sharebox#" "$CP/10-captive.conf" > "$R/etc/lighttpd/conf.d/10-captive.conf"
mkdir -p "$R/data/share/files"
echo '<script>alert(1)</script>' > "$R/data/share/files/evil.html"
echo 'hello' > "$R/data/share/files/hello.txt"

cat > "$R/usr/lib/sharebox/defaults.conf" <<EOF
hostname=sharebox.lan
ipv4=192.168.77.1/24
version=9.9.9
updates=1
EOF

setup() { # setup [captive_mode]
    printf 'captive_mode=%s\n' "${1:-popup}" > "$R/data/config/sharebox.conf"
    SHAREBOX_ROOT=$R SHAREBOX_MODEL=test sh "$FILES/sharebox-setup" 2>/dev/null
    sed -i -e "s#\"/usr/share/captive-portal#\"$R/usr/share/captive-portal#" "$R/run/sharebox/captive.conf"
    sed -i -e "s#\"/usr/share/captive-portal#\"$R/usr/share/captive-portal#" "$R/usr/share/captive-portal/silent.conf"
}

# Main config rewritten for the fake root, unprivileged port
sed -e "s#/run/sharebox#$R/run/sharebox#g" \
    -e "s#\"/usr/share/sharebox/www\"#\"$R/usr/share/sharebox/www\"#" \
    -e "s#\"/usr/lib/sharebox/cgi-bin/status\"#\"$R/usr/lib/sharebox/cgi-bin/status\"#" \
    -e "s#\"/etc/lighttpd/conf.d#\"$R/etc/lighttpd/conf.d#" \
    -e "s#^server.port = 80#server.port = $PORT#" \
    -e "s#^server.bind = \"0.0.0.0\"#server.bind = \"127.0.0.1\"#" \
    -e "s#^server.upload-dirs = .*#server.upload-dirs = ( \"$WORK\" )#" \
    "$TOP/recipes-webserver/lighttpd/files/lighttpd.conf" > "$R/etc/lighttpd/lighttpd.conf"
cat >> "$R/etc/lighttpd/lighttpd.conf" <<EOF
setenv.add-environment = ( "SHAREBOX_ROOT" => "$R", "SHAREBOX_DATA" => "$R/data" )
# test only: serve /files/ statically from /data/share/files
alias.url += ( "/files/" => "$R/data/share/files/" )
EOF

start() {
    [ -n "$pid" ] && kill "$pid" 2>/dev/null && sleep 0.3
    "$LIGHTTPD" -tt -f "$R/etc/lighttpd/lighttpd.conf" || { echo "FAIL: config test"; fail=$((fail + 1)); return 1; }
    SHAREBOX_ROOT=$R "$LIGHTTPD" -D -f "$R/etc/lighttpd/lighttpd.conf" 2> "$WORK/error.log" &
    pid=$!
    sleep 0.5
}

check() {
    d=$1; shift
    if "$@"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $d"; fi
}
# req HOST PATH [extra curl args]: writes headers to $WORK/h and body to $WORK/b
req() {
    h=$1 p=$2; shift 2
    curl -s -o "$WORK/b" -D "$WORK/h" -H "Host: $h" "$@" "http://127.0.0.1:$PORT$p"
}
hdr() { grep -qi -- "$1" "$WORK/h"; }
body() { grep -qF -- "$1" "$WORK/b"; }
status() { head -1 "$WORK/h" | grep -q " $1"; }

# --- popup mode ------------------------------------------------------------------
setup popup
start || exit 1
req connectivitycheck.gstatic.com /generate_204
check "popup: android 302" status 302
check "popup: location" hdr "^Location: http://sharebox.lan/"
req captive.apple.com /hotspot-detect.html
check "popup: apple 302" status 302
req sharebox.lan / -H "Accept-Language: fr-FR,fr;q=0.9,en;q=0.8"
check "lang: fr redirect" hdr "^Location: /fr/"
check "lang: 302" status 302
req sharebox.lan / -H "Accept-Language: zh-TW"
check "lang: zh-TW alias" hdr "^Location: /zh-Hant/"
req sharebox.lan / -H "Accept-Language: pt-BR"
check "lang: pt-BR subtag" hdr "^Location: /pt/"
req 192.168.77.1 / -H "Accept-Language: xx"
check "lang: unknown -> default" hdr "^Location: /en/"
req sharebox.lan /fr/
check "page fr 200" status 200
check "page nosniff" hdr "^X-Content-Type-Options: nosniff"
req sharebox.lan /fr/index.html.in
check "templates denied" status 403
req sharebox.lan /style.css
check "style.css" status 200
req sharebox.lan "/status?lang=de"
check "status 200" status 200
check "status german" body 'lang="de"'
check "status version" body "9.9.9"
req sharebox.lan /files/evil.html
check "active upload attachment" hdr "^Content-Disposition: attachment"
check "active upload sandbox" hdr "^Content-Security-Policy: sandbox"
req sharebox.lan /files/hello.txt
check "plain file no attachment" sh -c "! grep -qi '^Content-Disposition' '$WORK/h'"

# --- silent mode -----------------------------------------------------------------
setup silent
start || exit 1
req connectivitycheck.gstatic.com /generate_204
check "silent: android 204" status 204
req www.gstatic.com /generate_204
check "silent: gstatic 204" status 204
req captive.apple.com /hotspot-detect.html
check "silent: apple 200" status 200
check "silent: apple Success" body "<TITLE>Success</TITLE>"
req www.msftconnecttest.com /connecttest.txt
check "silent: windows" body "Microsoft Connect Test"
req detectportal.firefox.com /success.txt
check "silent: firefox success" body "success"
req detectportal.firefox.com /canonical.html
check "silent: firefox canonical" body "support.mozilla.org"
req nmcheck.gnome.org /check_network_status.txt
check "silent: NetworkManager" body "NetworkManager is online"
req networkcheck.kde.org /
check "silent: KDE" body "OK"
req connectivity-check.ubuntu.com /
check "silent: ubuntu 204" status 204
req example.com /some/page
check "silent: other URL 302" status 302
check "silent: other URL location" hdr "^Location: http://sharebox.lan/"
req sharebox.lan / -H "Accept-Language: ja"
check "silent: own host still negotiates" hdr "^Location: /ja/"

[ -s "$WORK/error.log" ] && grep -i "error\|warn" "$WORK/error.log" | head -5
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
