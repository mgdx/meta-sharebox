# Helpers shared by the ShareBox update scripts (POSIX sh, sourced).
# File formats are described in docs/ARCHITECTURE.md, section "Updates".

SHAREBOX_RUNDIR=${SHAREBOX_ROOT:-}/run/sharebox
SHAREBOX_UPDATE_CANDIDATE=$SHAREBOX_RUNDIR/update-candidate
SHAREBOX_UPDATE_STATUS=$SHAREBOX_RUNDIR/update-status
# Request drop box, created root:www 0730 by sharebox-config-status: only
# the web front end (group www) can queue a request, nobody else can list it.
# Watched by sharebox-update-install.path.
SHAREBOX_UPDATE_REQDIR=$SHAREBOX_RUNDIR/requests
SHAREBOX_UPDATE_REQUEST=$SHAREBOX_UPDATE_REQDIR/install
SHAREBOX_UPDATE_PENDING=${SHAREBOX_ROOT:-}/data/rauc/sharebox-pending-update

# Keep a value printable, on one line, without shell or HTML metacharacters,
# at most 200 characters.
sb_clean() {
    printf '%s' "$1" | tr '\n\t' '  ' | tr -cd 'A-Za-z0-9 ._:+/@(),=-' | cut -c1-200
}

# sb_write_kv <file> key value [key value ...]: atomically replace <file>
# with "key=value" lines (values cleaned), readable by the /status CGI.
sb_write_kv() {
    _f=$1
    shift
    mkdir -p "${_f%/*}"
    _tmp="$_f.tmp.$$"
    : > "$_tmp" || return 1
    while [ $# -ge 2 ]; do
        printf '%s=%s\n' "$1" "$(sb_clean "$2")" >> "$_tmp"
        shift 2
    done
    printf 'time=%s\n' "$(date +%s)" >> "$_tmp"
    chmod 0644 "$_tmp"
    mv -f "$_tmp" "$_f"
}

# sb_status <state> <message> [version]
sb_status() {
    sb_write_kv "$SHAREBOX_UPDATE_STATUS" state "$1" message "$2" version "${3:-}"
}

# sb_kv_get <file> <key>: value of key in a key=value file
sb_kv_get() {
    sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1
}

# sb_shell_get <text> <VAR>: value of VAR in "rauc --output-format=shell"
# output, without evaluating it.
sb_shell_get() {
    printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -n 1 | \
        sed -e "s/^'//" -e "s/'\$//" -e "s/'\\\\''/'/g"
}

# Compatible string of this system, from the RAUC system.conf in use
sb_system_compatible() {
    for _c in /etc/rauc/system.conf /run/rauc/system.conf /usr/lib/rauc/system.conf; do
        if [ -r "$_c" ]; then
            sed -n 's/^compatible=//p' "$_c" | head -n 1
            return 0
        fi
    done
}

# Boot name (A or B) of the running slot, from the kernel command line
sb_booted_slot() {
    for _a in $(cat /proc/cmdline); do
        case "$_a" in
        rauc.slot=*) echo "${_a#rauc.slot=}" ;;
        esac
    done
}

sb_running_version() {
    sed -n 's/^VERSION_ID=//p' /etc/os-release 2>/dev/null | tr -d '"'
}
