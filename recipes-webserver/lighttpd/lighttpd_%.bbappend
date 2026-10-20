# ShareBox: lighttpd as the HTTP front end. No TLS (offline box, no public
# certificate possible), no Lua, no access log; dedicated user, hardened unit,
# main configuration with runtime include and Accept-Language negotiation.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://lighttpd.service"

PACKAGECONFIG:remove = "openssl lua krb5 ldap mysql"

# No client logging on the box
RRECOMMENDS:${PN}:remove = "lighttpd-module-accesslog"

inherit useradd
USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /nonexistent --shell /sbin/nologin --user-group www"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/lighttpd.service ${D}${systemd_system_unitdir}/lighttpd.service
    sed -i -e 's,@SBINDIR@,${sbindir},g' \
        -e 's,@SYSCONFDIR@,${sysconfdir},g' \
        -e 's,@BASE_BINDIR@,${base_bindir},g' \
        ${D}${systemd_system_unitdir}/lighttpd.service
    install -d ${D}${sysconfdir}/lighttpd/conf.d
    # Example document root and sysvinit script are not used
    rm -rf ${D}/www ${D}${sysconfdir}/init.d ${D}${sysconfdir}/lighttpd.d
}

FILES:${PN} = "${sysconfdir} ${sbindir}"
RDEPENDS:${PN} += "sharebox-config"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
