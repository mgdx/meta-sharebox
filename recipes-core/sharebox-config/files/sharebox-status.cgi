#!/bin/sh
# /status CGI of the ShareBox (run by lighttpd mod_cgi as user www).
#
# Fills /usr/share/sharebox/templates/<lang>/status.html.in:
#   @@CLIENTS@@        devices currently seen on wlan0 (ARP table)
#   @@DISK_FREE@@      free space on /data
#   @@VERSION@@        DISTRO_VERSION
#   @@WARNINGS@@       <li> items from /run/sharebox/warnings
#   @@UPDATE_SECTION@@ status-update.html.in (@@BUNDLE@@) when an update
#                      bundle verified by the storage lot is waiting
#   @@UPDATE_RESULT@@  status-result-ok.html / status-result-error.html.in
#
# Update interface (implemented by the storage/RAUC lot):
#   /run/sharebox/update-bundle     absolute path of the bundle it verified
#   /run/sharebox/requests/install  written here with that path when a user
#                                   confirms; the storage lot watches it
#   /run/sharebox/update-result     "ok" or "error: <message>"
# Only the bundle listed in update-bundle can ever be requested.
#
# SHAREBOX_ROOT prefixes every path (tests).

set -u
ROOT=${SHAREBOX_ROOT:-}
RUN=$ROOT/run/sharebox
TPL=$ROOT/usr/share/sharebox/templates
I18N=$ROOT/usr/share/sharebox/i18n
DATA=${SHAREBOX_DATA:-$ROOT/data}

SHAREBOX_LANG=en
SHAREBOX_UPDATES=0
SHAREBOX_VERSION=""
# shellcheck disable=SC1091
[ -r "$RUN/env" ] && . "$RUN/env"

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

esc() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

# Shipped language code for a tag (case-insensitive), or fail
lang_code() {
    _t=$1
    case $_t in ''|*[!A-Za-z0-9-]*) return 1 ;; esac
    _lt=$(lower "$_t")
    while :; do
        if [ -r "$I18N/languages.txt" ]; then
            while IFS='	' read -r _c _dir _name || [ -n "$_c" ]; do
                case $_c in ''|'#'*) continue ;; esac
                if [ "$(lower "$_c")" = "$_lt" ] && [ -f "$TPL/$_c/status.html.in" ]; then
                    printf '%s' "$_c"; return 0
                fi
            done < "$I18N/languages.txt"
        fi
        if [ -r "$I18N/lang-aliases.txt" ]; then
            while IFS='	' read -r _a _c || [ -n "$_a" ]; do
                case $_a in ''|'#'*) continue ;; esac
                if [ "$(lower "$_a")" = "$_lt" ] && [ -f "$TPL/$_c/status.html.in" ]; then
                    printf '%s' "$_c"; return 0
                fi
            done < "$I18N/lang-aliases.txt"
        fi
        case $_lt in
            *-*) _lt=${_lt%-*} ;;
            *) return 1 ;;
        esac
    done
}

# Value of a field in an application/x-www-form-urlencoded string. Only
# plain characters are decoded; anything else makes the value empty.
field() {
    _q="&$2&"
    case $_q in *"&$1="*) ;; *) return 0 ;; esac
    _v=${_q#*"&$1="}
    _v=${_v%%&*}
    _v=$(printf '%s' "$_v" | sed -e 's/+/ /g' -e 's/%2[Bb]/+/g' -e 's/%2[Dd]/-/g' \
        -e 's/%2[Ee]/./g' -e 's/%5[Ff]/_/g')
    case $_v in *%*) return 0 ;; esac
    printf '%s' "$_v"
}

METHOD=${REQUEST_METHOD:-GET}
QUERY=${QUERY_STRING:-}
BODY=""
if [ "$METHOD" = POST ]; then
    len=${CONTENT_LENGTH:-0}
    case $len in ''|*[!0-9]*) len=0 ;; esac
    [ "$len" -gt 4096 ] && len=4096
    [ "$len" -gt 0 ] && BODY=$(head -c "$len")
fi

# Language: lang= parameter, then the first Accept-Language tag, then
# SHAREBOX_LANG, then English.
LANG_SEL=""
for cand in "$(field lang "$BODY")" "$(field lang "$QUERY")" \
            "$(printf '%s' "${HTTP_ACCEPT_LANGUAGE:-}" | sed -e 's/[,;].*//' -e 's/[[:space:]]//g')" \
            "$SHAREBOX_LANG" en; do
    LANG_SEL=$(lang_code "$cand") && break
    LANG_SEL=""
done

# --- update request -----------------------------------------------------------

P_UPDATE_RESULT=""
fragment() { # fragment NAME: prints a template fragment of the selected language
    for _l in "$LANG_SEL" en; do
        [ -n "$_l" ] && [ -f "$TPL/$_l/$1" ] && { cat "$TPL/$_l/$1"; return 0; }
    done
    return 1
}
result_error() {
    P_UPDATE_RESULT=$(fragment status-result-error.html.in | \
        while IFS= read -r l || [ -n "$l" ]; do
            e=$(esc "$1")
            case $l in
                *@@ERROR@@*) printf '%s%s%s\n' "${l%%@@ERROR@@*}" "$e" "${l#*@@ERROR@@}" ;;
                *) printf '%s\n' "$l" ;;
            esac
        done)
    [ -n "$P_UPDATE_RESULT" ] || P_UPDATE_RESULT="<p class=\"notice error\">$(esc "$1")</p>"
}

BUNDLE_PATH=""
if [ "$SHAREBOX_UPDATES" = 1 ] && [ -r "$RUN/update-bundle" ]; then
    IFS= read -r BUNDLE_PATH < "$RUN/update-bundle" || true
fi
BUNDLE_NAME=${BUNDLE_PATH##*/}

if [ "$METHOD" = POST ]; then
    action=$(field action "$BODY")
    bundle=$(field bundle "$BODY")
    if [ "$action" = install ] && [ -n "$BUNDLE_PATH" ] && [ "$bundle" = "$BUNDLE_NAME" ] \
       && [ -d "$RUN/requests" ]; then
        if printf '%s\n' "$BUNDLE_PATH" > "$RUN/requests/install.tmp" 2>/dev/null && \
           mv -f "$RUN/requests/install.tmp" "$RUN/requests/install"; then
            P_UPDATE_RESULT=$(fragment status-result-ok.html) || \
                P_UPDATE_RESULT='<p class="notice ok">OK</p>'
            BUNDLE_PATH=""
        else
            result_error "internal error"
        fi
    else
        result_error "invalid request"
    fi
elif [ -r "$RUN/update-result" ]; then
    IFS= read -r res < "$RUN/update-result" || true
    case ${res:-} in
        ok) P_UPDATE_RESULT=$(fragment status-result-ok.html) || P_UPDATE_RESULT="" ;;
        error*) msg=${res#error}; msg=${msg#:}; result_error "${msg# }" ;;
    esac
fi

# --- values ----------------------------------------------------------------------

clients=0
if [ -r /proc/net/arp ]; then
    clients=$(while read -r ip hw flags mac mask dev; do
        [ "$dev" = wlan0 ] && [ "$flags" = 0x2 ] && echo x
    done < /proc/net/arp | wc -l | tr -d ' ')
fi
P_CLIENTS=$clients

P_DISK_FREE="?"
kb=$(df -kP "$DATA" 2>/dev/null | sed -n '2{s/^[^ ]*  *[0-9]*  *[0-9]*  *\([0-9]*\).*/\1/p}')
case ${kb:-} in
    ''|*[!0-9]*) ;;
    *)
        if [ "$kb" -ge 1048576 ]; then
            P_DISK_FREE="$((kb / 1048576)).$(((kb % 1048576) * 10 / 1048576)) GB"
        else
            P_DISK_FREE="$((kb / 1024)) MB"
        fi
        ;;
esac

P_VERSION=$SHAREBOX_VERSION
if [ -z "$P_VERSION" ] && [ -r "$ROOT/usr/lib/os-release" ]; then
    P_VERSION=$(sed -n 's/^VERSION_ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$ROOT/usr/lib/os-release")
fi
P_VERSION=$(esc "$P_VERSION")

P_WARNINGS=""
if [ -s "$RUN/warnings" ]; then
    P_WARNINGS=$(while IFS= read -r w || [ -n "$w" ]; do
        [ -n "$w" ] && printf '<li>%s</li>' "$(esc "$w")"
    done < "$RUN/warnings")
fi

P_UPDATE_SECTION=""
if [ -n "$BUNDLE_PATH" ]; then
    P_BUNDLE=$(esc "$BUNDLE_NAME")
    P_UPDATE_SECTION=$(fragment status-update.html.in | \
        while IFS= read -r l || [ -n "$l" ]; do
            while :; do
                case $l in
                    *@@BUNDLE@@*) l="${l%%@@BUNDLE@@*}$P_BUNDLE${l#*@@BUNDLE@@}" ;;
                    *) break ;;
                esac
            done
            printf '%s\n' "$l"
        done)
fi

# --- render ------------------------------------------------------------------------

render_line() {
    out=""
    rest=$1
    while :; do
        case $rest in
            *@@*@@*) ;;
            *) break ;;
        esac
        pre=${rest%%@@*}
        tail=${rest#*@@}
        key=${tail%%@@*}
        case $key in
            CLIENTS|DISK_FREE|VERSION|WARNINGS|UPDATE_SECTION|UPDATE_RESULT)
                eval "val=\$P_$key"
                out="$out$pre$val"
                rest=${tail#*@@}
                ;;
            *)
                out="$out$pre@@"
                rest=$tail
                ;;
        esac
    done
    printf '%s%s\n' "$out" "$rest"
}

printf 'Content-Type: text/html; charset=utf-8\r\n'
printf 'Cache-Control: no-store\r\n'
printf 'Content-Language: %s\r\n' "${LANG_SEL:-en}"
printf '\r\n'

if [ -n "$LANG_SEL" ] && [ -f "$TPL/$LANG_SEL/status.html.in" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        render_line "$line"
    done < "$TPL/$LANG_SEL/status.html.in"
else
    cat <<EOF
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>ShareBox status</title>
<link rel="stylesheet" href="/style.css"></head><body><main>
<h1>Box status</h1>
$P_UPDATE_RESULT
<p>Connected devices: $P_CLIENTS</p>
<p>Free storage space: $P_DISK_FREE</p>
<p>Software version: $P_VERSION</p>
<ul class="warnings">$P_WARNINGS</ul>
$P_UPDATE_SECTION
</main></body></html>
EOF
fi
