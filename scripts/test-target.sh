#!/bin/sh
# SPDX-License-Identifier: MIT
# On-target acceptance checks of a ShareBox, run from a PC associated with
# the box Wi-Fi (specification, "Tests sur cible"). Covers what one PC can
# check by itself: wildcard DNS, captive portal probe answers, firewall,
# HTTP pages of the engine, and, with SSH access to a dev image, listening
# sockets, systemd sandboxing scores and both captive modes.
# Tests needing more hardware (several clients, real phones, power cuts,
# USB sticks, timing) are listed as SKIP at the end.
set -eu

usage() {
    cat <<EOF
Usage: $0 [options]

Run from a PC connected to the ShareBox Wi-Fi network.

  -a ADDR     box address (default: 192.168.77.1)
  -n NAME     box host name (default: sharebox.lan)
  -e ENGINE   image engine: base classic modular shareboxx library full
              (default: base)
  -c MODE     captive mode configured on the box: popup or silent
              (default: popup; the classic image always behaves as silent)
  -s SSH      SSH destination of a dev image (sharebox-dev), e.g.
              root@192.168.7.2 over Ethernet or USB gadget (SSH is never
              open on wlan0). Enables the ss, systemd-analyze and mode
              switching checks.
  -B          test both captive modes, switching the mode over SSH
              (needs -s; the Wi-Fi restarts, the PC must reconnect by itself)
  -i PEER     address of a second Wi-Fi client, for the client isolation
              check (ping and TCP scan must get nothing)
  -U          upload a small test file (modular, full); the file stays on
              the box, anonymous users cannot delete
  -f          full TCP port scan (nmap -p-, slow); default scans 1-10000
  -h          this help

Tools: curl and dig (required), nmap (firewall checks), ssh (with -s).
Exit status: 0 no failure, 1 at least one FAIL, 2 usage or missing tool.
EOF
}

ADDR=192.168.77.1
NAME=sharebox.lan
ENGINE=base
MODE=popup
SSH=""
BOTH=0
PEER=""
UPLOAD=0
FULLSCAN=0

while getopts "a:n:e:c:s:Bi:Ufh" opt; do
    case $opt in
        a) ADDR=$OPTARG ;;
        n) NAME=$OPTARG ;;
        e) ENGINE=$OPTARG ;;
        c) MODE=$OPTARG ;;
        s) SSH=$OPTARG ;;
        B) BOTH=1 ;;
        i) PEER=$OPTARG ;;
        U) UPLOAD=1 ;;
        f) FULLSCAN=1 ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 0 ] || { usage >&2; exit 2; }

case $ENGINE in base|classic|modular|shareboxx|library|full) ;; *) echo "error: unknown engine '$ENGINE'" >&2; exit 2 ;; esac
case $MODE in popup|silent) ;; *) echo "error: mode must be popup or silent" >&2; exit 2 ;; esac
if [ "$BOTH" -eq 1 ] && [ -z "$SSH" ]; then
    echo "error: -B needs -s (the mode is switched over SSH)" >&2
    exit 2
fi
for t in curl dig; do
    command -v "$t" >/dev/null 2>&1 || { echo "error: $t is required" >&2; exit 2; }
done
have() { command -v "$1" >/dev/null 2>&1; }

PASS=0 FAIL=0 WARN=0 SKIP=0
pass() { PASS=$((PASS + 1)); echo "PASS  $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL  $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN  $*"; }
skip() { SKIP=$((SKIP + 1)); echo "SKIP  $*"; }
section() { echo; echo "== $*"; }

WORK=$(mktemp -d)
RESTORE_MODE=""
cleanup() {
    if [ -n "$RESTORE_MODE" ]; then
        echo "restoring the captive mode configuration on the box"
        ssh_box "$RESTORE_MODE" >/dev/null 2>&1 || echo "warning: could not restore /data/config/sharebox.conf" >&2
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

ssh_box() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH" "$1"; }

# req HOST PATH [curl args...]: GET through the box whatever HOST resolves
# to; sets CODE, LOCATION, and the body in $WORK/body
req() {
    _h=$1 _p=$2
    shift 2
    CODE=$(curl -s -o "$WORK/body" -D "$WORK/headers" -w '%{http_code}' --max-time 10 \
        --resolve "$_h:80:$ADDR" "$@" "http://$_h$_p" 2>/dev/null) || CODE=${CODE:-000}
    LOCATION=$(sed -n 's/^[Ll]ocation:[[:space:]]*//p' "$WORK/headers" 2>/dev/null | tr -d '\r' | head -n 1)
}
header() { # header NAME: value of a response header of the last req
    tr -d '\r' < "$WORK/headers" | awk -v h="$1" '
        { i = index($0, ":") }
        i > 0 && tolower(substr($0, 1, i - 1)) == tolower(h) {
            v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit
        }'
}

# --- reachability ------------------------------------------------------------

section "Reachability ($ADDR, $NAME, engine $ENGINE)"
req "$ADDR" /
if [ "$CODE" = 000 ]; then
    fail "no HTTP answer from $ADDR: is this PC associated with the box Wi-Fi?"
    echo
    echo "PASS $PASS, FAIL $FAIL, WARN $WARN, SKIP $SKIP"
    exit 1
fi
pass "HTTP answer from $ADDR (status $CODE)"

# --- DNS -----------------------------------------------------------------------

section "DNS (wildcard, TTL 0)"
rand=check-$$-$(date +%s).example
for q in "$rand" "www.example.org" "$NAME"; do
    for proto in udp tcp; do
        flag=""
        [ "$proto" = udp ] || flag=+tcp
        # shellcheck disable=SC2086
        ans=$(dig @"$ADDR" "$q" A +noall +answer +time=3 +tries=1 $flag 2>/dev/null | awk '$4 == "A" { print $2, $5; exit }')
        ttl=${ans%% *}
        ip=${ans#* }
        if [ -z "$ans" ]; then
            fail "dig $q ($proto): no answer"
        elif [ "$ip" != "$ADDR" ]; then
            fail "dig $q ($proto): $ip instead of $ADDR"
        elif [ "$ttl" != 0 ]; then
            fail "dig $q ($proto): TTL $ttl instead of 0"
        else
            pass "dig $q ($proto) -> $ADDR, TTL 0"
        fi
    done
done
ans=$(dig @"$ADDR" "$rand" AAAA +short +time=3 +tries=1 2>/dev/null || true)
if [ -z "$ans" ]; then pass "no AAAA answer (IPv4 only network)"; else warn "AAAA answer for $rand: $ans"; fi

# --- captive portal ------------------------------------------------------------

# host|path|silent status|silent body (substring, empty: not checked)|who
PROBES='connectivitycheck.gstatic.com|/generate_204|204||Android
clients3.google.com|/generate_204|204||Android
www.google.com|/gen_204|204||Chrome
connectivity-check.ubuntu.com|/|204||Ubuntu
captive.apple.com|/hotspot-detect.html|200|Success|Apple
www.apple.com|/library/test/success.html|200|Success|Apple
www.msftconnecttest.com|/connecttest.txt|200|Microsoft Connect Test|Windows
www.msftncsi.com|/ncsi.txt|200|Microsoft NCSI|Windows
detectportal.firefox.com|/canonical.html|200|support.mozilla.org|Firefox
detectportal.firefox.com|/success.txt|200|success|Firefox
nmcheck.gnome.org|/check_network_status.txt|200|NetworkManager is online|NetworkManager
networkcheck.kde.org|/|200|OK|KDE
fedoraproject.org|/static/hotspot.txt|200|OK|Fedora'

captive_checks() { # captive_checks MODE
    _mode=$1
    # In classic and shareboxx the engine implements the portal itself
    # (luffy: always silent; ShareBoxx: its own rules): report, do not fail.
    _strict=1
    case $ENGINE in classic|shareboxx) _strict=0 ;; esac
    _bad() { if [ "$_strict" -eq 1 ]; then fail "$@"; else warn "$@ (engine $ENGINE implements its own portal)"; fi; }

    printf '%s\n' "$PROBES" > "$WORK/probes"
    while IFS='|' read -r host path scode sbody who; do
        req "$host" "$path"
        if [ "$_mode" = popup ]; then
            case $LOCATION in
                "http://$NAME/"*) ok=1 ;;
                *) ok=0 ;;
            esac
            if [ "$CODE" = 302 ] && [ "$ok" -eq 1 ]; then
                pass "popup: $who http://$host$path -> 302 $LOCATION"
            else
                _bad "popup: $who http://$host$path -> $CODE ${LOCATION:-(no Location)}, expected 302 to http://$NAME/"
            fi
        else
            if [ "$CODE" != "$scode" ]; then
                _bad "silent: $who http://$host$path -> $CODE, expected $scode"
            elif [ -n "$sbody" ] && ! grep -qF "$sbody" "$WORK/body"; then
                _bad "silent: $who http://$host$path -> $CODE without '$sbody' in the body"
            else
                pass "silent: $who http://$host$path -> $CODE"
            fi
        fi
    done < "$WORK/probes"

    # Any other foreign request lands on the home page in both modes
    req www.example.com /some/page.html
    case $LOCATION in "http://$NAME/"*) ok=1 ;; *) ok=0 ;; esac
    if [ "$CODE" = 302 ] && [ "$ok" -eq 1 ]; then
        pass "$_mode: foreign page -> 302 to http://$NAME/"
    else
        _bad "$_mode: foreign page -> $CODE ${LOCATION:-(no Location)}, expected 302 to http://$NAME/"
    fi
    _nc=$(header Cache-Control)
    case $_nc in *no-store*) pass "$_mode: redirect not cacheable (Cache-Control: $_nc)" ;; *) _bad "$_mode: redirect without Cache-Control: no-store" ;; esac
}

# Switch the captive mode over SSH and wait for the box to come back
set_mode() { # set_mode MODE
    _m=$1
    if [ -z "$RESTORE_MODE" ]; then
        if ssh_box 'test -e /data/config/sharebox.conf'; then
            ssh_box 'cp -p /data/config/sharebox.conf /data/config/.sharebox.conf.test-target' || return 1
            RESTORE_MODE='mv -f /data/config/.sharebox.conf.test-target /data/config/sharebox.conf && systemctl restart sharebox-setup'
        else
            RESTORE_MODE='rm -f /data/config/sharebox.conf && systemctl restart sharebox-setup'
        fi
    fi
    ssh_box "touch /data/config/sharebox.conf && sed -i '/^[[:space:]]*captive_mode[[:space:]]*=/d' /data/config/sharebox.conf && echo captive_mode=$_m >> /data/config/sharebox.conf && systemctl restart sharebox-setup" || return 1
    echo "captive mode set to $_m, waiting for the box (the Wi-Fi restarts)..."
    sleep 5
    _i=0
    while [ "$_i" -lt 60 ]; do
        if [ "$(ssh_box '. /run/sharebox/env && printf %s "$SHAREBOX_CAPTIVE_MODE"' 2>/dev/null)" = "$_m" ]; then
            req "$ADDR" /
            [ "$CODE" = 000 ] || return 0
        fi
        sleep 2
        _i=$((_i + 1))
    done
    return 1
}

if [ "$ENGINE" = classic ] && [ "$MODE" = popup ] && [ "$BOTH" -eq 0 ]; then
    echo
    echo "note: luffy (classic) always answers the probes as silent; testing silent"
    MODE=silent
fi

if [ "$BOTH" -eq 1 ]; then
    for m in popup silent; do
        section "Captive portal, $m mode"
        if set_mode "$m"; then
            captive_checks "$m"
        else
            fail "could not switch the box to $m mode over SSH"
        fi
    done
else
    section "Captive portal, $MODE mode (as configured on the box)"
    captive_checks "$MODE"
    other=popup
    [ "$MODE" = popup ] && other=silent
    skip "$other mode: set captive_mode=$other on the box and run again with -c $other, or use -s ... -B"
fi

# --- firewall --------------------------------------------------------------------

section "Firewall"
_t0=$(date +%s)
if curl -s -o /dev/null --max-time 5 "https://$ADDR/" 2>/dev/null; then
    rc=0
else
    rc=$?
fi
_t1=$(date +%s)
if [ "$rc" = 7 ] && [ $((_t1 - _t0)) -le 2 ]; then
    pass "https://$ADDR/ refused at once (TCP reset)"
else
    fail "https://$ADDR/: curl exit $rc after $((_t1 - _t0)) s, expected an immediate reset (exit 7)"
fi

# nmap_ports STATE PROTO FILE: ports in STATE from a grepable (-oG) nmap
# output ("Host: ...<TAB>Ports: 53/open/tcp//domain///, 80/open/...")
nmap_ports() {
    [ -f "$3" ] || return 0
    awk -F'\t' '{ for (i = 1; i <= NF; i++) if ($i ~ /^Ports: /) { sub(/^Ports: /, "", $i); print $i } }' "$3" |
        tr ',' '\n' | awk -F/ -v s="$1" -v p="$2" '{ sub(/^ +/, "", $1) } $2 == s && $3 == p { print $1 }' |
        sort -n | paste -sd ' ' -
}

if have nmap; then
    if [ "$FULLSCAN" -eq 1 ]; then ports=1-65535; else ports=1-10000; fi
    echo "nmap TCP scan of $ADDR, ports $ports..."
    nmap -Pn -n -sT -p "$ports" -T4 --max-retries 1 -oG "$WORK/nmap" "$ADDR" >/dev/null 2>&1 || true
    open=$(nmap_ports open tcp "$WORK/nmap")
    closed=$(nmap_ports closed tcp "$WORK/nmap")
    if [ "$open" = "53 80" ]; then
        pass "open TCP ports: $open"
    else
        fail "open TCP ports: '${open:-none}', expected '53 80'"
    fi
    if [ "$closed" = 443 ]; then
        pass "443 closed (reset), every other port filtered"
    else
        fail "closed (reset) TCP ports: '${closed:-none}', expected '443' only"
    fi
    if [ "$(id -u)" -eq 0 ]; then
        nmap -Pn -n -sU -p 53,67,68,123,161,1900,5353 --max-retries 1 -oG "$WORK/nmapu" "$ADDR" >/dev/null 2>&1 || true
        uopen=$(nmap_ports open udp "$WORK/nmapu")
        case " $uopen " in
            *" 53 "*) pass "UDP 53 answers (open UDP ports among the sample: $uopen)" ;;
            *) fail "UDP 53 not seen open (sample: '${uopen:-none}')" ;;
        esac
    else
        skip "UDP scan (needs root for nmap -sU)"
    fi
else
    skip "TCP and UDP port scans (nmap not installed)"
fi

# --- HTTP pages ------------------------------------------------------------------

section "HTTP pages ($ENGINE)"
expect() { # expect DESCRIPTION PATH CODES...
    _d=$1 _p=$2
    shift 2
    req "$NAME" "$_p"
    for _c in "$@"; do
        [ "$CODE" = "$_c" ] && { pass "$_d: GET http://$NAME$_p -> $CODE"; return 0; }
    done
    fail "$_d: GET http://$NAME$_p -> $CODE, expected $*"
    return 1
}
case $ENGINE in
    base|modular|library|full)
        req "$NAME" / -H 'Accept-Language: fr-FR,fr;q=0.9,en;q=0.5'
        case "$CODE $LOCATION" in
            "302 "*/fr/*) pass "/ with Accept-Language fr -> 302 $LOCATION" ;;
            *) fail "/ with Accept-Language fr -> $CODE ${LOCATION:-}, expected 302 to /fr/" ;;
        esac
        if [ "$(header X-Content-Type-Options)" = nosniff ]; then pass "X-Content-Type-Options: nosniff on /"; else fail "no X-Content-Type-Options: nosniff on /"; fi
        expect "home page" /en/ 200
        expect "how it works" /en/how-it-works.html 200
        expect "stylesheet" /style.css 200
        expect "status page" /status 200
        if [ "$CODE" = 200 ] && grep -qi 'version' "$WORK/body"; then pass "/status shows a version"; fi
        req "$NAME" /status -X POST --data 'action=install&bundle=..%2F..%2Fetc%2Fpasswd'
        case $CODE in
            200|400|403|405) if grep -qi 'passwd' "$WORK/body"; then fail "/status POST echoes the bundle path"; else pass "/status POST with a forged bundle name refused ($CODE)"; fi ;;
            *) fail "/status POST -> $CODE" ;;
        esac
        expect "files under /data are not CGI" /files/x.cgi 403 404
        ;;
    classic|shareboxx)
        expect "home page" / 200
        ;;
esac
case $ENGINE in
    modular|full)
        expect "file share" /files/ 200
        expect "chat client" /chat/ 200
        CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --resolve "$NAME:80:$ADDR" \
            -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
            -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "http://$NAME/socket" 2>/dev/null) || true
        if [ "$CODE" = 101 ]; then pass "chat WebSocket /socket -> 101"; else fail "chat WebSocket /socket -> ${CODE:-000}, expected 101"; fi
        ;;
esac
case $ENGINE in
    full) expect "upload area" /upload/ 200 ;;
    library) expect "read-only file share" /files/ 200 ;;
esac
case $ENGINE in
    library|full)
        expect "offline library" /wiki/ 200 302
        ;;
esac

if [ "$UPLOAD" -eq 1 ]; then
    case $ENGINE in
        modular|full)
            if [ "$ENGINE" = full ]; then up=/upload; else up=/files/upload; fi
            f=test-target-$$-$(date +%s).txt
            printf 'ShareBox test-target upload %s\n' "$f" > "$WORK/up"
            req "$NAME" "$up/$f" -T "$WORK/up"
            case $CODE in 200|201|204) pass "upload PUT $up/$f -> $CODE" ;; *) fail "upload PUT $up/$f -> $CODE" ;; esac
            req "$NAME" "$up/$f"
            if [ "$CODE" = 200 ] && cmp -s "$WORK/up" "$WORK/body"; then pass "uploaded file read back"; else fail "uploaded file read back -> $CODE"; fi
            req "$NAME" "$up/$f" -X DELETE
            case $CODE in 401|403|405) pass "anonymous DELETE refused ($CODE)" ;; *) fail "anonymous DELETE -> $CODE, expected a refusal" ;; esac
            ;;
        *) skip "upload test (-U) only implemented for modular and full" ;;
    esac
fi

# --- client isolation ------------------------------------------------------------

section "Client isolation"
if [ -n "$PEER" ]; then
    if ping -c 3 -W 2 "$PEER" >/dev/null 2>&1; then
        fail "ping to the other client $PEER answered (ap_isolate)"
    else
        pass "no ping answer from the other client $PEER"
    fi
    if have nmap; then
        nmap -Pn -n -sT -p 22,80,135,139,443,445,5353,8080,62078 --max-retries 1 -oG "$WORK/peer" "$PEER" >/dev/null 2>&1 || true
        if grep -q '/open/' "$WORK/peer"; then fail "TCP ports of $PEER reachable"; else pass "no TCP port of $PEER reachable"; fi
    else
        skip "TCP scan of $PEER (nmap not installed)"
    fi
else
    skip "client isolation (needs a second Wi-Fi client: -i <its address>)"
fi

# --- on the box, over SSH (dev image) ------------------------------------------------

section "On the box (SSH)"
if [ -z "$SSH" ]; then
    skip "listening sockets, systemd-analyze security (need a dev image: -s root@<ethernet address>)"
elif ! ssh_box true; then
    fail "cannot connect with ssh $SSH"
else
    ssh_box 'ss -lntuH 2>/dev/null || netstat -lntu 2>/dev/null' > "$WORK/ss" || true
    if [ ! -s "$WORK/ss" ]; then
        warn "neither ss nor netstat available on the box"
    else
        bad=""
        set -f
        while read -r l; do
            case $l in Proto*|Active*|Netid*|'') continue ;; esac
            # ss: netid state recvq sendq local peer; netstat: proto recvq sendq local foreign [state]
            set -- $l
            case $1 in tcp|tcp6|udp|udp6) ;; *) continue ;; esac
            if [ "$2" = LISTEN ] || [ "$2" = UNCONN ]; then local=$5; else local=$4; fi
            port=${local##*:}
            host=${local%:*}
            host=${host%%%*}
            case $host in
                127.*|'[::1]'|::1|'[::ffff:127.'*) continue ;;
            esac
            case $port in
                53|67|80) ;;
                22|68|546) echo "INFO  dev only: $1 $local" ;;
                *) bad="$bad $1:$local" ;;
            esac
        done < "$WORK/ss"
        set +f
        if [ -z "$bad" ]; then
            pass "nothing listens outside localhost except 53, 67, 80 (and dev SSH/DHCP client)"
        else
            fail "unexpected listening sockets:$bad"
        fi
    fi
    units=$(ssh_box "systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk '{print \$1}'" 2>/dev/null || true)
    for u in hostapd dnsmasq lighttpd luffy shareboxx dufs dufs-ro ergo kiwix-serve; do
        case " $(echo $units) " in *" $u.service "*) ;; *) continue ;; esac
        score=$(ssh_box "systemd-analyze security --no-pager $u.service 2>/dev/null | sed -n 's/.*Overall exposure level for [^:]*: \\([0-9.]*\\).*/\\1/p'" 2>/dev/null || true)
        if [ -z "$score" ]; then
            warn "systemd-analyze security $u.service: no score"
        elif awk -v s="$score" 'BEGIN { exit !(s < 3.0) }'; then
            pass "systemd-analyze security $u.service: $score"
        else
            fail "systemd-analyze security $u.service: $score, expected below 3.0"
        fi
    done
    w=$(ssh_box 'cat /run/sharebox/warnings 2>/dev/null' || true)
    if [ -z "$w" ]; then pass "no configuration warning"; else warn "configuration warnings on the box: $w"; fi
fi

# --- not covered ----------------------------------------------------------------------

section "Not covered by this script"
skip "boot time to beacon (needs a stopwatch or a second Wi-Fi interface in monitor mode)"
skip "8 simultaneous clients, 10 min of HTTP traffic, maximum client count (needs several Wi-Fi clients)"
skip "real captive portal pop-ups on Android, iOS, Windows, Firefox (needs the devices)"
skip "1 GB upload with Wi-Fi cut and resume, upload above the limit (long, run by hand)"
skip "chat with 8 clients and 100 messages each"
skip "Kiwix article and search timing with wikipedia_fr_all_nopic"
skip "USB stick insertion and hot removal, update bundles (needs sticks and signed/unsigned bundles)"
skip "20 power cuts during writes"
skip "lynis and kernel-hardening-checker review"

echo
echo "PASS $PASS, FAIL $FAIL, WARN $WARN, SKIP $SKIP"
[ "$FAIL" -eq 0 ]
