#!/bin/sh
# Unit tests for sharebox-setup, run on the build host with a fake root.
# Usage: scripts/test-sharebox-setup.sh [shell]   (default: sh; try "busybox sh")
set -u

SHELL_CMD=${1:-sh}
TOP=$(cd "$(dirname "$0")/.." && pwd)
FILES=$TOP/recipes-core/sharebox-config/files
SETUP=$FILES/sharebox-setup
WORK=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT

fail=0
pass=0

mkroot() {
    R=$WORK/root
    rm -rf "$R"
    mkdir -p "$R/usr/lib/sharebox" "$R/usr/share/sharebox" "$R/data/config" "$R/run" \
             "$R/usr/share/captive-portal"
    cp -r "$FILES/i18n" "$R/usr/share/sharebox/i18n"
    rm -rf "$R/usr/share/sharebox/i18n/strings" "$R/usr/share/sharebox/i18n/templates"
    mkdir -p "$R/usr/share/sharebox/www"
    for d in "$FILES"/www/*/; do
        l=$(basename "$d")
        mkdir -p "$R/usr/share/sharebox/www/$l"
        : > "$R/usr/share/sharebox/www/$l/index.html"
    done
    : > "$R/usr/share/captive-portal/popup.conf"
    : > "$R/usr/share/captive-portal/silent.conf"
    cat > "$R/usr/lib/sharebox/defaults.conf" <<EOF
ssid=
lang=
country=
channel=6
band=2.4
upload_max=2G
captive_mode=popup
hostname=sharebox.lan
ipv4=192.168.77.1/24
engine=base
updates=1
version=0.1.0
EOF
}

# run [model]: runs sharebox-setup with $R/data/config/sharebox.conf
run() {
    SHAREBOX_ROOT=$R SHAREBOX_MODEL=${1:-"Raspberry Pi 4 Model B Rev 1.4"} \
        $SHELL_CMD "$SETUP" 2> "$WORK/stderr" || { echo "setup failed:"; cat "$WORK/stderr"; }
}

conf() { printf '%s\n' "$@" > "$R/data/config/sharebox.conf"; }
defaults() { printf '%s\n' "$@" >> "$R/usr/lib/sharebox/defaults.conf"; }

check() { # check <description> <command...>
    d=$1; shift
    if "$@"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $d"; fi
}
has() { grep -qxF -- "$2" "$R/run/sharebox/$1"; }
hasnt() { ! grep -q -- "$2" "$R/run/sharebox/$1"; }
warned() { grep -q -- "$1" "$R/run/sharebox/warnings"; }
nowarn() { [ ! -s "$R/run/sharebox/warnings" ]; }
envis() { grep -qxF -- "$1=\"$2\"" "$R/run/sharebox/env"; }

hex() { printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'; }

# 1. defaults: world domain, 2.4 GHz channel 6, English SSID
mkroot; run
check "default no country_code" hasnt hostapd.conf country_code
check "default hw_mode=g" has hostapd.conf hw_mode=g
check "default channel 6" has hostapd.conf channel=6
check "default ssid" has hostapd.conf "ssid2=$(hex 'ShareBox - Share Freely')"
check "default lang en" envis SHAREBOX_LANG en
check "default no warning" nowarn
check "default upload bytes" envis SHAREBOX_UPLOAD_MAX 2147483648
check "default request size" has lighttpd-runtime.conf "server.max-request-size = 2097152"
check "dhcp range" has dnsmasq.conf "dhcp-range=192.168.77.10,192.168.77.250,255.255.255.0,12h"
check "dns wildcard" has dnsmasq.conf "address=/#/192.168.77.1"
check "captive popup" has captive.conf 'include "/usr/share/captive-portal/popup.conf"'
check "ap_isolate" has hostapd.conf ap_isolate=1

# 2. band=5 without country is refused
mkroot; conf band=5 channel=36; run
check "5GHz refused without country" has hostapd.conf hw_mode=g
check "5GHz warning" warned "5 GHz requires a country"
check "36 reset to 6 on 2.4" has hostapd.conf channel=6
check "channel warning" warned "channel '36'"

# 3. channel 12/13 without country reset to 6
mkroot; conf channel=13; run
check "ch13 world reset" has hostapd.conf channel=6
check "ch13 world warning" warned "without a country"

# 4. channel 13 with country is fine, country_code emitted, lang from country
mkroot; conf country=fr channel=13; run
check "country_code FR" has hostapd.conf country_code=FR
check "ieee80211d" has hostapd.conf ieee80211d=1
check "ch13 FR" has hostapd.conf channel=13
check "lang from FR" envis SHAREBOX_LANG fr
check "French ssid" has hostapd.conf "ssid2=$(hex "$(cat "$FILES/i18n/ssid-fr.txt")")"
check "FR no warning" nowarn

# 5. band=5 with country
mkroot; conf country=DE band=5 channel=44; run
check "5GHz DE" has hostapd.conf hw_mode=a
check "5GHz ch44" has hostapd.conf channel=44
check "5GHz HT40+" has hostapd.conf "ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40]"
check "lang de" envis SHAREBOX_LANG de

# 6. band=5 with an invalid channel -> 36
mkroot; conf country=DE band=5 channel=6; run
check "5GHz bad channel" has hostapd.conf channel=36
check "5GHz bad channel warning" warned "5 GHz channel"

# 7. band=5 on a board without 5 GHz
mkroot; conf country=DE band=5; run "Raspberry Pi Zero 2 W Rev 1.0"
check "Zero 2 W stays 2.4" has hostapd.conf hw_mode=g
check "Zero 2 W warning" warned "no 5 GHz radio"

# 8. multilingual country -> English, lang override wins
mkroot; conf country=BE; run
check "BE -> en" envis SHAREBOX_LANG en
mkroot; conf country=FR lang=ja; run
check "lang override" envis SHAREBOX_LANG ja
mkroot; conf lang=pt-BR; run
check "lang subtag fallback" envis SHAREBOX_LANG pt
mkroot; conf lang=zh-TW; run
check "lang alias" envis SHAREBOX_LANG zh-Hant
mkroot; conf lang=xx; run
check "unknown lang warning" warned "language 'xx'"
check "unknown lang -> en" envis SHAREBOX_LANG en
mkroot; defaults lang=es; run
check "build lang" envis SHAREBOX_LANG es

# 9. language without SSID file falls back to the English SSID
mkroot; conf lang=pa; run
check "pa lang" envis SHAREBOX_LANG pa
check "pa english ssid" has hostapd.conf "ssid2=$(hex 'ShareBox - Share Freely')"

# 10. SSID too long for 32 bytes falls back to English
mkroot; printf 'ShareBox - 這是一個非常長的名稱\n' > "$R/usr/share/sharebox/i18n/ssid-zh-Hant.txt"; conf lang=zh-Hant; run
check "long translated ssid fallback" has hostapd.conf "ssid2=$(hex 'ShareBox - Share Freely')"

# 11. explicit SSID, quoting, invalid SSID
mkroot; conf 'ssid="My "box" $HOME"'; run
check "explicit ssid" has hostapd.conf "ssid2=$(hex 'My "box" $HOME')"
check "env escaping" grep -qx 'SHAREBOX_SSID="My \\"box\\" \\$HOME"' "$R/run/sharebox/env"
check "env sourceable" sh -c ". '$R/run/sharebox/env' && [ \"\$SHAREBOX_SSID\" = 'My \"box\" \$HOME' ]"
mkroot; conf 'ssid=0123456789012345678901234567890123'; run
check "ssid too long warning" warned "1 to 32 bytes"
check "ssid too long fallback" has hostapd.conf "ssid2=$(hex 'ShareBox - Share Freely')"

# 12. upload_max parsing
mkroot; conf upload_max=500M; run
check "500M" envis SHAREBOX_UPLOAD_MAX 524288000
check "500M kb" has lighttpd-runtime.conf "server.max-request-size = 512000"
mkroot; conf upload_max=0; run
check "0 disables" envis SHAREBOX_UPLOAD_MAX 0
check "0 small requests" has lighttpd-runtime.conf "server.max-request-size = 64"
mkroot; conf upload_max=1g; run
check "1g" envis SHAREBOX_UPLOAD_MAX 1073741824
mkroot; conf upload_max=lots; run
check "bad size warning" warned "upload_max 'lots'"
check "bad size default" envis SHAREBOX_UPLOAD_MAX 2147483648

# 13. robustness: CRLF, BOM, comments, unknown keys, invalid country
mkroot; printf '\357\273\277# comment\r\ncountry = it \r\nfoo=bar\r\nnoequal\r\n' > "$R/data/config/sharebox.conf"; run
check "CRLF+BOM country" has hostapd.conf country_code=IT
check "unknown key warning" warned "unknown key 'foo'"
check "no equal warning" warned "no '='"
mkroot; conf country=France; run
check "bad country warning" warned "country 'France'"
check "bad country ignored" hasnt hostapd.conf country_code
mkroot; defaults country=CH; run
check "build country" has hostapd.conf country_code=CH
mkroot; defaults country=CH; conf country=00; run
check "runtime 00 clears build country" hasnt hostapd.conf country_code

# 14. silent captive mode and language rules
mkroot; conf captive_mode=silent; run
check "silent include" has captive.conf 'include "/usr/share/captive-portal/silent.conf"'
check "lang rule fr" grep -q '"/fr/"' "$R/run/sharebox/lighttpd-runtime.conf"
check "alias before dir" sh -c "grep -n 'zh-hant-tw' '$R/run/sharebox/lighttpd-runtime.conf' | head -1 | cut -d: -f1 > '$WORK/a'; grep -n '\^\\\\s\*zh-hant(' '$R/run/sharebox/lighttpd-runtime.conf' | head -1 | cut -d: -f1 > '$WORK/b'; [ \$(cat '$WORK/a') -lt \$(cat '$WORK/b') ]"

check "host regex" has lighttpd-runtime.conf 'var.sharebox_host_regex = "^(sharebox\.lan|192\.168\.77\.1)(:[0-9]+)?$"'

# 15. hostile values cannot inject configuration lines
mkroot; printf 'ssid=a\nchannel=6\ninterface=eth0\n' > "$R/data/config/sharebox.conf"; run
check "no injected interface" has hostapd.conf interface=wlan0
check "injection key refused" warned "unknown key 'interface'"

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
