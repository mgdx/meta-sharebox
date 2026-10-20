# Deviations from the specification

## Modular engine

### Sriracha (forum) is not packaged

The specification points at `github.com/jacobhq/sriracha` (Go, LGPL-3.0,
SQLite) as an optional forum. That repository does not exist. The only
matching project is Sriracha by Trevor Slocum
(`codeberg.org/tslocum/sriracha`, v2.2.0, Go, LGPL-3.0, no CGO), an
imageboard and forum server, but it does not fit the box:

- PostgreSQL is its only supported database. Its pure Go SQLite driver
  (modernc.org/sqlite) is only used to import and export posts. Running a
  PostgreSQL server on a Raspberry Pi box is far outside the RAM and image
  size budget of the `modular` and `full` images.
- It must be served at `/`: running it under a sub-path such as `/forum/`
  is explicitly unsupported upstream.
- It creates a default super-administrator account (`admin`/`admin`) that
  must be changed through the web interface, which is reachable by everyone
  on the open network.

`packagegroup-sharebox-engine-modular` therefore installs no forum and there
is no `SHAREBOX_FORUM` switch. The `full` image does not get a forum either.
Port 8080 and `/forum/` stay reserved in `docs/ARCHITECTURE.md` for a later
forum engine.

### Ergo: vendored modules instead of generated go-mods.inc

Ergo commits all its Go dependencies in `vendor/` (with
`vendor/modules.txt`). The recipe builds with `-mod=vendor` and does not
inherit `go-mod-update-modules`: there is no `ergo-go-mods.inc`, nothing is
fetched with `gomod://`. `ergo-licenses.inc` lists the licenses of the
vendored modules actually linked into the binary; it was produced with
`go list -deps -tags sqlite .` and `oe.license_finder`, unknown entries
checked by hand (see the header of the file).

### Ergo: SQLite history without CGO

Ergo 2.19.1 supports SQLite for persistent history with the pure Go driver
modernc.org/sqlite (build tag `sqlite`), so the binary is built with
`CGO_ENABLED=0`. History of `#sharebox` is stored in `/data/chat/ergo.db`
(as in the specification), server state in `/data/chat/ircd.db` (buntdb).
Direct messages are never written to disk, history expires after one week.

There are no accounts (registration and authentication disabled), so
`#sharebox` cannot be registered and Ergo has no "always-on" channel:
every client auto-joins `#sharebox` (`channels.auto-join`) and the
persistent history (`unregistered-channels: true`) is replayed by gamja on
join. The `i18n` build tag is left out: Ergo server messages are in
English.

### gamja: no prebuilt dist/

gamja release tarballs (sr.ht and Codeberg, latest tag `v1.0.0-beta.11`,
the project moved to `codeberg.org/emersion/gamja`) contain the source tree
only, without `dist/`. No reliable prebuilt artifact is published (the CI
artifacts expire). gamja does not need its Parcel build though: the
sources are native ES modules that only import
`node_modules/{preact,htm,linkifyjs}/dist/*.js`. The recipe fetches the
tagged source from git and the three npm registry tarballs pinned to the
versions of the upstream `package-lock.json` (SHA-256 in the recipe), and
installs only the files the browser loads. No Node.js, no vendored binary
blob. `LICENSE` is `AGPL-3.0-only & MIT & Apache-2.0` (gamja, preact and
linkifyjs, htm).

The recipe is `gamja_git.bb` with `PV = "1.0.0~beta.11"` (the `~` keeps
the pre-release ordering below a future 1.0.0).

### gamja: relative WebSocket URL

`config.json` uses `"url": "/socket"` instead of `ws://sharebox.lan/socket`.
gamja turns the path into a WebSocket URL on the host the page was loaded
from, so it keeps working when `SHAREBOX_HOSTNAME` is changed or when the
box is reached by its IP address.

### gamja is served with mod_alias

The `/chat/` snippet uses `alias.url` to map `/chat/` to `/usr/share/gamja/`
(the specification install path), so `mod_alias` is added to the modules
allowed in snippets (`docs/ARCHITECTURE.md`). It is built into lighttpd
1.4.82 but must be listed in `server.modules`.

### dufs packaging

One recipe, three packages: `dufs` (binary and `dufs.service`, read-write
public share on port 5000), `dufs-ro` (only `dufs-ro.service`, read-only
on port 5001, used by the library and full engines) and `dufs-lighttpd`
(`/files/` proxy to port 5000). `dufs-ro` ships no lighttpd snippet: the
library engine maps `/files/` to port 5001 itself.

dufs has no upload size limit: lighttpd `server.max-request-size` is the
only limit. `dufs.service` starts dufs through `/usr/libexec/dufs/dufs-start`
(POSIX shell) so that `--allow-upload` is dropped when
`SHAREBOX_UPLOAD_MAX` is `0`. Anonymous users may write only under
`/data/share/upload` (`--auth '@/,/upload:rw'`); without `--allow-delete`
dufs refuses deletes, moves and overwrites of non-empty files but still
accepts resumed uploads (PATCH) of a partial file. `--allow-symlink` is set
so that the `/data/share/usb` link to the USB stick can be followed.
