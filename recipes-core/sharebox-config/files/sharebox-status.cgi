#!/bin/sh
# /status CGI of the ShareBox (run by lighttpd mod_cgi as user www).
#
# Fills /usr/share/sharebox/templates/<lang>/status.html.in:
#   @@CLIENTS@@        devices currently seen on wlan0 (ARP table)
#   @@DISK_FREE@@      free space on /data
#   @@VERSION@@        DISTRO_VERSION
#   @@WARNINGS@@       <li> items from /run/sharebox/warnings
#   @@UPDATE_SECTION@@ status-update.html.in (@@BUNDLE@@) when an update
#                      bundle verified by the USB hook is waiting
#   @@UPDATE_RESULT@@  status-result-ok.html / status-result-error.html.in
#
# Update interface (sharebox-update package, docs/ARCHITECTURE.md "Updates"):
#   /run/sharebox/update-candidate  key=value, written by the USB hook 50-rauc
#                                   (state=ready|invalid, file, name, error)
#   /run/sharebox/update-status     key=value, written by the root install
#                                   service and sharebox-healthcheck (state,
#                                   message, version)
#   /usr/lib/sharebox/sharebox-install-update "<bundle name>"
#                                   run on a confirmed POST; as an
#                                   unprivileged user it only queues the
#                                   request in /run/sharebox/requests/install
#                                   for sharebox-update-install.service. The
#                                   name is only compared with the candidate,
#                                   never used as a path.
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

result_ok() {
    P_UPDATE_RESULT=$(fragment status-result-ok.html) || \
        P_UPDATE_RESULT='<p class="notice ok">OK</p>'
}
kv() { # kv FILE KEY: value of KEY in a key=value file
    sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1
}

INSTALL_CMD=$ROOT/usr/lib/sharebox/sharebox-install-update
UPDATES=0
[ "$SHAREBOX_UPDATES" = 1 ] && [ -x "$INSTALL_CMD" ] && UPDATES=1

ST_STATE="" ST_MSG="" CAND_STATE="" CAND_FILE="" CAND_NAME="" CAND_ERR=""
if [ "$UPDATES" = 1 ]; then
    if [ -r "$RUN/update-status" ]; then
        ST_STATE=$(kv "$RUN/update-status" state)
        ST_MSG=$(kv "$RUN/update-status" message)
    fi
    if [ -r "$RUN/update-candidate" ]; then
        CAND_STATE=$(kv "$RUN/update-candidate" state)
        CAND_FILE=$(kv "$RUN/update-candidate" file)
        CAND_NAME=$(kv "$RUN/update-candidate" name)
        CAND_ERR=$(kv "$RUN/update-candidate" error)
    fi
fi
# No new request while an installation or a rollback is in progress
BUSY=0
case $ST_STATE in installing|rebooting|rolling-back) BUSY=1 ;; esac

if [ "$METHOD" = POST ]; then
    action=$(field action "$BODY")
    bundle=$(field bundle "$BODY")
    if [ "$UPDATES" = 1 ] && [ "$action" = install ] && [ "$BUSY" = 0 ]; then
        # Only queues the request; refused unless "bundle" is the name of
        # the candidate verified by the USB hook.
        rc=0
        msg=$("$INSTALL_CMD" "$bundle" 2>/dev/null) || rc=$?
        msg=$(printf '%s\n' "$msg" | head -n 1)
        if [ "$rc" = 0 ]; then
            result_ok
            BUSY=1
        else
            result_error "${msg:-internal error}"
        fi
    else
        result_error "invalid request"
    fi
else
    case $ST_STATE in
        installing|rebooting) result_ok ;;
        failed|rolling-back|rolled-back) result_error "$ST_MSG" ;;
    esac
    if [ -z "$P_UPDATE_RESULT" ] && [ "$CAND_STATE" = invalid ]; then
        result_error "${CAND_NAME:+$CAND_NAME: }$CAND_ERR"
    fi
fi

# The install form only for a verified bundle whose stick is still there
BUNDLE_NAME=""
if [ "$UPDATES" = 1 ] && [ "$BUSY" = 0 ] && [ "$CAND_STATE" = ready ] && \
   [ -n "$CAND_NAME" ] && [ -f "$ROOT$CAND_FILE" ]; then
    BUNDLE_NAME=$CAND_NAME
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
if [ -n "$BUNDLE_NAME" ]; then
    P_BUNDLE=$(esc "$BUNDLE_NAME")
    P_UPDATE_SECTION=$(fragment status-update.html.in | \
        while IFS= read -r l || [ -n "$l" ]; do
            # The value is never rescanned (it may contain "@@")
            o=""
            while :; do
                case $l in
                    *@@BUNDLE@@*) o="$o${l%%@@BUNDLE@@*}$P_BUNDLE"; l=${l#*@@BUNDLE@@} ;;
                    *) break ;;
                esac
            done
            printf '%s%s\n' "$o" "$l"
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
