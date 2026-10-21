SUMMARY = "ShareBox modular engine: dufs, Ergo and gamja behind lighttpd"
DESCRIPTION = "Reference sharing stack: public files, WebDAV and anonymous \
resumable upload with dufs (/files/), IRC chat with Ergo over WebSocket \
(/socket) and the gamja web client (/chat/). lighttpd itself comes from \
packagegroup-sharebox-frontend."
LICENSE = "MIT"

inherit packagegroup

# No forum: Sriracha is not packaged, see docs/deviations.md ("Modular engine").
RDEPENDS:${PN} = " \
    dufs-rw \
    ergo \
    ergo-lighttpd \
    gamja \
    gamja-lighttpd \
"

# /files/ -> writable dufs (port 5000). A recommendation, not a dependency:
# the full image drops it (BAD_RECOMMENDATIONS) and installs
# dufs-ro-lighttpd (/files/, read-only) and dufs-upload-lighttpd (/upload/).
RRECOMMENDS:${PN} = "dufs-lighttpd"
