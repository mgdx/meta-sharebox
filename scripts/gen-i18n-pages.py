#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate the ShareBox home pages and SSID files from the i18n sources.

Developer-host tool only, never installed in an image. Run it after editing
anything under recipes-core/sharebox-config/files/i18n/{languages.txt,
strings/,templates/} and commit its output:

    scripts/gen-i18n-pages.sh

Inputs (under recipes-core/sharebox-config/files/i18n/):
    languages.txt          code<TAB>dir<TAB>native name, one language per line
    strings/<code>.txt     key=value string table per language (en is the
                           reference, missing keys fall back to English)
    templates/*.html       page templates, {{key}} = string, {{@x}} = generated

Outputs:
    i18n/ssid-<code>.txt   "ShareBox - <slogan>", only when it fits 32 bytes
    www/<code>/            index.html.in, how-it-works.html, status.html.in,
                           status-update.html.in, status-result-ok.html,
                           status-result-error.html.in, engine-<engine>.html
    www/en/index.html      rendered fallback (base engine)
"""

import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = os.path.join(ROOT, "recipes-core", "sharebox-config", "files")
I18N = os.path.join(FILES, "i18n")
WWW = os.path.join(FILES, "www")

SSID_PREFIX = "ShareBox - "
SSID_MAX_BYTES = 32
ENGINES = ("base", "classic", "modular", "shareboxx", "library", "full")

# template name -> (output name, page title key or None for fragments)
PAGES = {
    "index.html": ("index.html.in", ""),
    "how-it-works.html": ("how-it-works.html", "how_title"),
    "status.html": ("status.html.in", "status_title"),
}
FRAGMENTS = {
    "status-update.html": "status-update.html.in",
    "status-result-ok.html": "status-result-ok.html",
    "status-result-error.html": "status-result-error.html.in",
}
FRAGMENTS.update({"engine-%s.html" % e: "engine-%s.html" % e for e in ENGINES})

MARKERS = {
    "{http}": '<code dir="ltr">http://</code>',
    "{https}": '<code dir="ltr">https://</code>',
    "{example}": '<code dir="ltr">http://sharebox.lan</code>',
}

warnings = []


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def load_languages():
    langs = []
    for n, line in enumerate(read(os.path.join(I18N, "languages.txt")).splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) != 3 or cols[1] not in ("ltr", "rtl"):
            sys.exit("languages.txt:%d: expected code<TAB>ltr|rtl<TAB>name" % n)
        langs.append(tuple(cols))
    return langs


def load_strings(code):
    path = os.path.join(I18N, "strings", code + ".txt")
    table = {}
    if not os.path.exists(path):
        return None
    for n, line in enumerate(read(path).splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep:
            sys.exit("%s:%d: missing '='" % (path, n))
        table[key.strip()] = value.strip()
    return table


def to_html(code, text):
    out = html.escape(text, quote=False)
    if code == "fr":
        # French typography: no-break space before high punctuation.
        out = re.sub(r" ([:;?!»])", "\u00a0\\1", out)
        out = re.sub(r"(«) ", "\\1\u00a0", out)
    for marker, repl in MARKERS.items():
        out = out.replace(marker, repl)
    return out


def render(template, code, strings, extra):
    def sub(m):
        key = m.group(1)
        if key.startswith("@"):
            return extra[key[1:]]
        if key not in strings:
            sys.exit("template uses unknown string key %r" % key)
        return to_html(code, strings[key])

    return re.sub(r"\{\{(@?[a-z_]+)\}\}", sub, template)


def lang_links(langs, current):
    items = []
    for code, direction, name in langs:
        attrs = ' hreflang="%s" lang="%s"' % (code, code)
        if direction == "rtl":
            attrs += ' dir="rtl"'
        if code == current:
            attrs += ' aria-current="true"'
        items.append('<li><a href="/%s/"%s>%s</a></li>' % (code, attrs, html.escape(name)))
    return "\n".join(items)


def main():
    langs = load_languages()
    english = load_strings("en")
    if english is None:
        sys.exit("strings/en.txt is required")
    tdir = os.path.join(I18N, "templates")
    templates = {name: read(os.path.join(tdir, name)) for name in list(PAGES) + list(FRAGMENTS)}
    layout = read(os.path.join(tdir, "layout.html"))
    fallback_ssid = []

    for code, direction, _name in langs:
        own = load_strings(code)
        if own is None:
            warnings.append("%s: no strings file, language skipped" % code)
            continue
        missing = [k for k in english if k not in own]
        unknown = [k for k in own if k not in english]
        if missing:
            warnings.append("%s: %d missing keys use English: %s" % (code, len(missing), " ".join(missing)))
        if unknown:
            warnings.append("%s: unknown keys ignored: %s" % (code, " ".join(unknown)))
        strings = dict(english)
        strings.update({k: v for k, v in own.items() if k in english})

        # SSID
        ssid = SSID_PREFIX + strings["ssid_slogan"]
        ssid_path = os.path.join(I18N, "ssid-%s.txt" % code)
        if len(ssid.encode("utf-8")) <= SSID_MAX_BYTES:
            write(ssid_path, ssid + "\n")
        else:
            fallback_ssid.append("%s (%d bytes)" % (code, len(ssid.encode("utf-8"))))
            if os.path.exists(ssid_path):
                os.remove(ssid_path)

        base = {"lang": code, "dir": direction}
        outdir = os.path.join(WWW, code)
        for name, out in FRAGMENTS.items():
            write(os.path.join(outdir, out), render(templates[name], code, strings, base))

        for name, (out, title_key) in PAGES.items():
            body = render(templates[name], code, strings, base).rstrip("\n")
            title = "ShareBox"
            if title_key:
                title = "%s \u2013 ShareBox" % html.escape(strings[title_key])
            extra = dict(base)
            extra.update({
                "title": title,
                "body": body,
                "langs": lang_links(langs, code),
                "cur_home": ' aria-current="page"' if name == "index.html" else "",
                "cur_how": ' aria-current="page"' if name == "how-it-works.html" else "",
                "cur_status": ' aria-current="page"' if name == "status.html" else "",
            })
            write(os.path.join(outdir, out), render(layout, code, strings, extra))

    # Rendered English fallback home page (captive portal default target).
    en_dir = os.path.join(WWW, "en")
    page = read(os.path.join(en_dir, "index.html.in"))
    links = read(os.path.join(en_dir, "engine-base.html")).rstrip("\n")
    write(os.path.join(en_dir, "index.html"), page.replace("@@ENGINE_LINKS@@", links))

    for w in warnings:
        print("warning: " + w, file=sys.stderr)
    if fallback_ssid:
        print("SSID too long, English fallback: " + ", ".join(fallback_ssid))
    print("generated %d languages" % len(langs))


if __name__ == "__main__":
    main()
