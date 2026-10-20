#!/bin/sh
# SPDX-License-Identifier: MIT
# Check the ShareBox i18n data and pages:
#  - languages.txt format (code, ltr/rtl, native name; RTL set),
#  - every ssid-<lang>.txt is one line "ShareBox - ..." of at most 32 bytes,
#  - every language has a complete page set with its placeholders,
#  - country-lang.csv only names shipped languages, one line per country,
#  - pages are well-formed HTML (xmllint --html, when installed).
# POSIX sh, usable on the developer host and in CI. Exit status 1 on error.
set -u

top=$(cd "$(dirname "$0")/.." && pwd)
files="$top/recipes-core/sharebox-config/files"
i18n="$files/i18n"
www="$files/www"
errors=0
fallback=""

err() {
	echo "ERROR: $*" >&2
	errors=$((errors + 1))
}

# Byte length of the first line of a file, without the newline.
bytes() {
	head -n 1 "$1" | tr -d '\n' | wc -c | tr -d ' '
}

[ -f "$i18n/languages.txt" ] || { err "missing $i18n/languages.txt"; exit 1; }
[ -f "$www/style.css" ] || err "missing www/style.css"
[ -f "$www/en/index.html" ] || err "missing rendered fallback www/en/index.html"

tab=$(printf '\t')
codes=""
count=0
while IFS="$tab" read -r code dir name extra; do
	case "$code" in ''|'#'*) continue ;; esac
	count=$((count + 1))
	codes="$codes $code"
	[ -n "$name" ] && [ -z "$extra" ] || err "languages.txt: bad line for '$code'"
	case "$code" in
	ar|ur|fa|ps) want=rtl ;;
	*) want=ltr ;;
	esac
	[ "$dir" = "$want" ] || err "languages.txt: $code should be $want, not '$dir'"

	ssid="$i18n/ssid-$code.txt"
	if [ -f "$ssid" ]; then
		n=$(bytes "$ssid")
		[ "$n" -le 32 ] || err "ssid-$code.txt is $n bytes (max 32)"
		[ "$(wc -l < "$ssid" | tr -d ' ')" -le 1 ] || err "ssid-$code.txt has more than one line"
		case "$(head -n 1 "$ssid")" in
		"ShareBox - "?*) ;;
		*) err "ssid-$code.txt does not start with 'ShareBox - '" ;;
		esac
	elif [ "$code" = en ]; then
		err "ssid-en.txt is required (fallback SSID)"
	else
		fallback="$fallback $code"
	fi

	d="$www/$code"
	for f in index.html.in how-it-works.html status.html.in \
	    status-update.html.in status-result-ok.html status-result-error.html.in \
	    engine-base.html engine-classic.html engine-modular.html \
	    engine-shareboxx.html engine-library.html engine-full.html; do
		[ -s "$d/$f" ] || err "$code: missing $f"
	done
	for p in ENGINE_LINKS; do
		grep -q "@@$p@@" "$d/index.html.in" 2>/dev/null || err "$code: index.html.in lacks @@$p@@"
	done
	for p in CLIENTS DISK_FREE VERSION WARNINGS UPDATE_SECTION UPDATE_RESULT; do
		grep -q "@@$p@@" "$d/status.html.in" 2>/dev/null || err "$code: status.html.in lacks @@$p@@"
	done
	grep -q "@@BUNDLE@@" "$d/status-update.html.in" 2>/dev/null || err "$code: status-update.html.in lacks @@BUNDLE@@"
	grep -q "@@ERROR@@" "$d/status-result-error.html.in" 2>/dev/null || err "$code: status-result-error.html.in lacks @@ERROR@@"
	for f in index.html.in how-it-works.html status.html.in; do
		grep -q "<html lang=\"$code\" dir=\"$dir\">" "$d/$f" 2>/dev/null || err "$code: $f lacks lang/dir attributes"
	done
done < "$i18n/languages.txt"

# Country to language table.
csv="$i18n/country-lang.csv"
if [ -f "$csv" ]; then
	[ "$(head -n 1 "$csv")" = "country,lang" ] || err "country-lang.csv: bad header"
	dups=$(tail -n +2 "$csv" | cut -d, -f1 | sort | uniq -d)
	[ -z "$dups" ] || err "country-lang.csv: duplicate countries: $dups"
	tail -n +2 "$csv" | while IFS=, read -r cc lang; do
		case "$cc" in
		[A-Z][A-Z]) ;;
		*) echo "ERROR: country-lang.csv: bad country code '$cc'" >&2; echo x ;;
		esac
		if [ -n "$lang" ]; then
			case " $codes " in
			*" $lang "*) ;;
			*) echo "ERROR: country-lang.csv: $cc uses unshipped language '$lang'" >&2; echo x ;;
			esac
		fi
	done > "${TMPDIR:-/tmp}/check-i18n.$$"
	n=$(wc -l < "${TMPDIR:-/tmp}/check-i18n.$$" | tr -d ' ')
	rm -f "${TMPDIR:-/tmp}/check-i18n.$$"
	errors=$((errors + n))
else
	err "missing country-lang.csv"
fi

# HTML well-formedness.
if command -v xmllint > /dev/null 2>&1; then
	for f in "$www"/*/*.html "$www"/*/*.html.in; do
		out=$(xmllint --html --noout "$f" 2>&1)
		[ -z "$out" ] || err "xmllint: $f: $out"
	done
else
	echo "note: xmllint not found, HTML not checked" >&2
fi

echo "languages: $count"
[ -z "$fallback" ] || echo "SSID falls back to English for:$fallback"
if [ "$errors" -gt 0 ]; then
	echo "$errors error(s)" >&2
	exit 1
fi
echo "i18n check OK"
