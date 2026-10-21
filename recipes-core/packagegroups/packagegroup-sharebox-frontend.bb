SUMMARY = "ShareBox HTTP front end"
DESCRIPTION = "lighttpd with the modules allowed by the layer, the captive \
portal rules and the /status CGI. Installed by the images whose port 80 is \
served by lighttpd (base, modular, library, full)."
LICENSE = "MIT"

inherit packagegroup

# mod_rewrite, mod_redirect, mod_access, mod_alias, mod_indexfile,
# mod_staticfile and mod_setenv are built into lighttpd 1.4.82.
RDEPENDS:${PN} = " \
    lighttpd \
    lighttpd-module-cgi \
    lighttpd-module-proxy \
    lighttpd-module-webdav \
    captive-portal \
    sharebox-config-status \
"
