# Deviations from the specification

## Luffy (classic engine)

Upstream: <https://github.com/et0and/luffy>, GPL-3.0 (`GPL-3.0-only` in the
recipe, upstream states "GPLv3"), Go standard library only (no module
dependency). No release tag exists: the recipe pins commit
`9523301d7ad2cedbf7a735b328f3a2d3ef678e66` (2026-09-19) with
`PV = "1.0.0+git"` (version from upstream's Makefile).

- **Configuration file location.** The specification has `sharebox-config`
  write `/etc/piratebox/piratebox.conf`. The luffy recipe instead generates
  `/run/sharebox/luffy/piratebox.conf` at every start (`ExecStartPre=`
  `luffy-gen-config`, run as `sharebox`) from `/run/sharebox/env`
  (`SHAREBOX_HOSTNAME` -> `HOST`, `SHAREBOX_ADDR` -> `IP`/`NET`/`IP_SHORT`,
  `SHAREBOX_UPLOAD_MAX` -> `UPLOAD_MAX_SIZE_MB` and `DROOPY_ENABLED`). If
  `/etc/piratebox/piratebox.conf` exists (for example written by
  `sharebox-config`) it is sourced as site customisation, but the keys that
  must match the sandbox (paths, ports, network management) are forced
  after it. luffy thus depends on nothing but `/run/sharebox/env`.
- **Data layout.** `PIRATEBOX_FOLDER=/data/luffy` (chat, forum, web content,
  created by `luffy.tmpfiles`), `UPLOADFOLDER=/data/share/upload`, and the
  `/Shared` listing shows the whole `/data/share` (new `DIRLIST_FOLDER` key,
  see the patch below).
- **`luffy serve`, not `luffy start`.** luffy can manage the interface,
  hostapd, dnsmasq and iptables; in ShareBox the base system owns those, so
  the unit runs the web server only.
- **Uploads on port 80.** Upstream serves the droopy upload form on a second
  port (8080) and the start page iframe points to `http://luffy.lan:8080`.
  The firewall only opens port 80, so the layer patch
  `0001-Serve-uploads-on-the-main-listener.patch` mounts the form under
  `/upload/` on the main listener and `DROOPY_PORT="0"` disables the second
  listener. To be proposed upstream.
- **Captive probes.** luffy always answers the probes as "Internet is
  available" (`/generate_204` -> 204, Apple `Success`): it behaves like
  `SHAREBOX_CAPTIVE_MODE=silent` whatever the setting (the specification
  already calls silent mode native to luffy). Popup mode is not available
  in the classic image.
- **`go-mod-update-modules`.** With no module dependency, the class would
  write `LICENSE += "& "` (invalid); `luffy-licenses.inc` and
  `luffy-go-mods.inc` are therefore kept by hand (both empty).
- **Unit.** `ReadWritePaths=/data/luffy /data/share/upload` rather than the
  whole `/data`. `AF_NETLINK` is allowed for `iw dev wlan0 station dump`
  (connected clients counter; `iw` is an `RRECOMMENDS`).

## Shareboxx

Upstream: <https://github.com/dividebysandwich/shareboxx>, GPL-2.0
(`GPL-2.0-only`), latest tag `v1.1.4` (2026-05-07, commit
`e216e16b730c19eefee36d8cec1f0740458d3aea`), as in the specification.

### Decision on the wasm32 open point: option (b)

Leptos needs two builds: the server (`ssr` feature, target binary) and the
client (`hydrate` feature, `wasm32-unknown-unknown`, then `wasm-bindgen`
and, for the stylesheet, dart-sass). Option (a) would require adding a
wasm32 target to the Wrynose Rust toolchain (rust 1.94.1, its
`libstd-rs` and the rust target config only know Linux targets), a
`wasm-bindgen-cli-native` recipe pinned to the exact `wasm-bindgen` crate
version, `cargo-leptos-native`, and dart-sass, which is a Dart/Node.js
program that the specification forbids as `-native`. That is a lot of
toolchain work for 1 MB of portable assets.

Retained: **(b) with upstream release assets.** Upstream's release CI runs
`cargo leptos build --release` and publishes `.deb` packages whose
`/var/lib/shareboxx/site/` holds the client bundle (`pkg/shareboxx.wasm`,
`pkg/shareboxx.js`, `pkg/shareboxx.css`, images). Nothing binary is stored
in the layer:

- `shareboxx-web_1.1.4.bb` (allarch) fetches
  `shareboxx_1.1.4_arm64.deb` from the GitHub release (sha256 checked by the
  fetcher), unpacks only `site/`, checks every installed file against
  `files/shareboxx-web-1.1.4.sha256` and installs it in
  `/usr/share/shareboxx/site`. The server binary of the package is ignored.
- `shareboxx_1.1.4.bb` builds the server from the git tag with
  `cargo.bbclass`: `--no-default-features --features ssr --bin shareboxx`,
  `--release` (default profile, unwinding kept so that a panicking request
  does not abort the whole server).

### Keeping server and client in step

The client calls server functions at URLs computed at compile time, and
the hydration script must load the right file names:

1. **Cargo.lock.** Upstream does not commit a `Cargo.lock` (it is in
   `.gitignore`). The layer ships `files/Cargo.lock`, resolved with the
   registry as it was when the release was built:
   `cargo -Zunstable-options generate-lockfile --publish-time 2026-05-07T13:00:00Z`
   then `cargo update -p actix-http --precise 3.12.1`. Every crate version
   that appears in the panic paths of the upstream arm64 binary (98 crates)
   and of the upstream wasm bundle (35 crates: leptos 0.8.19, server_fn
   0.8.12, wasm-bindgen 0.2.121, ...) matches this lock file.
2. **Server function hash.** server_fn appends
   `xxh64(CARGO_MANIFEST_DIR + ":" + module_path)` to every endpoint. The
   bundle was built in `/home/runner/work/shareboxx/shareboxx`, giving
   `/api/<name>12246998792517303403`. The recipe exports
   `SERVER_FN_OVERRIDE_KEY = "/home/runner/work/shareboxx/shareboxx"`, which
   server_fn uses instead of `CARGO_MANIFEST_DIR`, so the server registers
   the same URLs (verified by computing the hash).
3. **Output name.** cargo-leptos exports `LEPTOS_OUTPUT_NAME` at compile
   time; without it Leptos would load `shareboxx_bg.wasm`. The recipe
   exports `LEPTOS_OUTPUT_NAME = "shareboxx"`.

### Regenerating for a new upstream version

1. Bump `PV`/`SRCREV` in `shareboxx_<ver>.bb` and rename both recipes.
2. Fetch the new `.deb`, update `SRC_URI[deb.sha256sum]`,
   `SRC_URI[license.sha256sum]` and `files/shareboxx-web-<ver>.sha256`
   (`sha256sum` of the files under `var/lib/shareboxx/site`).
3. Regenerate the lock file at the release time of the tag (see 1. above)
   with a nightly cargo, compare its versions with the crate paths found in
   the upstream binaries (`strings` on `usr/bin/shareboxx` and
   `pkg/shareboxx.wasm`, look for `index.crates.io-*/<crate>-<version>/`)
   and pin outliers with `cargo update --precise`.
4. `scripts/cargo-lock-to-crates-inc.py files/Cargo.lock shareboxx >
   shareboxx-crates.inc`.
5. Check that the hash in the wasm (`strings pkg/shareboxx.wasm | grep /api/`)
   still matches `SERVER_FN_OVERRIDE_KEY`; upstream CI paths may change.

### Other changes

- Layer patch `0001-Make-host-name-and-upload-limit-configurable.patch`:
  - upstream redirects every request whose host is not `shareboxx.lan`;
    the host name now comes from `SHAREBOXX_HOSTNAME` (unit: from
    `SHAREBOX_HOSTNAME`);
  - the multipart limit (hard coded 10 GiB) comes from
    `SHAREBOXX_UPLOAD_MAX` (unit: `SHAREBOX_UPLOAD_MAX` bytes, 0 rejects
    uploads);
  - **security fix**: `upload_path` and the file name were concatenated to
    `./files/` without checks, allowing `../` to write anywhere the service
    can write; they are now rejected if absolute or containing `..`;
  - `df --output=size,avail -B1` (GNU only) replaced by `df -P -k`, which
    busybox understands.
- Data: shareboxx works relative to its working directory
  `/data/shareboxx` (chat.json, stats.json, config.json, uploads.db);
  `./files` is a symlink to `/data/share/upload` (created by
  `shareboxx.tmpfiles`). The files shown by ShareBoxx are therefore the
  anonymous upload area, not the whole `/data/share` (which is root owned in
  the data layout); see open issues.
- Upstream's `.deb` postinst and `shareboxx-setup` (hostapd, dnsmasq,
  iptables) are not used.
- `LICENSE` of the server lists GPL-2.0-only and the licenses of the
  statically linked crates (audited from crates.io for the 380 crates of the
  lock file; for "MIT OR Apache-2.0" crates MIT is retained, being
  GPL-2.0 compatible): `MIT & BSD-3-Clause & BSL-1.0 & MPL-2.0 &
  Unicode-3.0 & Zlib & CC0-1.0`. Only the upstream `LICENSE` is checksummed.
- Machines: 64-bit only (`COMPATIBLE_MACHINE` on the image), as in the
  specification.
- Reproducibility: the client bundle is upstream's binary output; the
  server is built in Yocto and covered by the usual reproducibility checks.
