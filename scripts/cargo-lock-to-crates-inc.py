#!/usr/bin/env python3
"""Generate a bitbake <pn>-crates.inc from a Cargo.lock file."""
import sys
import tomllib

lock = tomllib.load(open(sys.argv[1], "rb"))
pn = sys.argv[2]
crates = []
for p in lock["package"]:
    src = p.get("source", "")
    if src == "registry+https://github.com/rust-lang/crates.io-index":
        crates.append((p["name"], p["version"], p["checksum"]))
    elif src:
        sys.exit("unsupported source %s for %s" % (src, p["name"]))
crates.sort()
out = ["# Generated from Cargo.lock by scripts/cargo-lock-to-crates-inc.py for %s" % pn,
       "# Do not edit by hand.", "", "SRC_URI += \" \\"]
for n, v, _ in crates:
    out.append("    crate://crates.io/%s/%s \\" % (n, v))
out.append("\"")
out.append("")
for n, v, c in crates:
    out.append('SRC_URI[%s-%s.sha256sum] = "%s"' % (n, v, c))
print("\n".join(out))
