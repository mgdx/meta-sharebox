SUMMARY = "ShareBox 'shareboxx' engine: ShareBoxx (Rust, Leptos)"
DESCRIPTION = "ShareBoxx serves files, uploads and a live chat on port 80 \
by itself; lighttpd is not installed. The web client needs JavaScript and \
WebAssembly."
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = "shareboxx shareboxx-web"
