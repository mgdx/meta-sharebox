SUMMARY = "ShareBox runtime configuration, home pages and translations"
DESCRIPTION = "Bakes the SHAREBOX_* build variables into \
/usr/lib/sharebox/defaults.conf and installs sharebox-setup, which merges \
them at boot with /data/config/sharebox.conf and writes the hostapd, \
dnsmasq and lighttpd runtime configuration into /run/sharebox. Also ships \
the static home pages (one directory per language), the /status CGI, the \
data tree, the sysctl hardening and the wlan0 network configuration."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Data files under files/ (maintained by the i18n lot, picked up without any
# change to this recipe):
#   i18n/languages.txt       "code<TAB>ltr|rtl<TAB>native name", one per language
#   i18n/ssid-<code>.txt     one line: the full generated SSID ("ShareBox - ...")
#                            (at most 32 bytes, else English is used)
#   i18n/country-lang.csv    header "country,lang"; lang empty when the country
#                            has several official languages (English is used)
#   i18n/lang-aliases.txt    "alias<TAB>code": browser tags without a directory
#   www/style.css            served at /style.css
#   www/<code>/index.html.in home page; "@@ENGINE_LINKS@@" alone on a line is
#                            replaced with www/<code>/engine-<engine>.html
#   www/<code>/engine-<engine>.html  engine cards, one <li> per line; cards
#                            with class optional-upload are dropped when
#                            uploads are off
#   www/<code>/how-it-works.html     final page
#   www/<code>/status.html.in, status-update.html.in, status-result-ok.html,
#   status-result-error.html.in      /status CGI templates (not served)
# i18n/strings/ and i18n/templates/ are developer sources, not installed.

SRC_URI = " \
    file://sharebox-setup \
    file://sharebox-setup.service \
    file://sharebox-status.cgi \
    file://tmpfiles-sharebox.conf \
    file://tmpfiles-sharebox-status.conf \
    file://tmpfiles-sharebox-devaccess.conf \
    file://90-sharebox.conf \
    file://10-wlan0.network.in \
    file://50-sharebox-dev.nft \
    file://i18n \
    file://www \
"

S = "${UNPACKDIR}"

inherit allarch systemd useradd

SHAREBOX_ENGINES = "base classic modular shareboxx library full"
do_configure[noexec] = "1"
do_compile[noexec] = "1"

# Build time defaults, same "key=value" format as /data/config/sharebox.conf.
# The engine is recorded by the installed sharebox-config-<engine> package
# (one allarch build serves every image).
python sharebox_write_defaults () {
    band = '5' if d.getVar('SHAREBOX_5GHZ') == '1' else '2.4'
    items = [
        ('ssid', d.getVar('SHAREBOX_SSID') or ''),
        ('lang', d.getVar('SHAREBOX_LANG') or ''),
        ('country', d.getVar('SHAREBOX_COUNTRY') or ''),
        ('channel', d.getVar('SHAREBOX_CHANNEL') or '6'),
        ('band', band),
        ('upload_max', d.getVar('SHAREBOX_UPLOAD_MAX') or '2G'),
        ('captive_mode', d.getVar('SHAREBOX_CAPTIVE_MODE') or 'popup'),
        ('hostname', d.getVar('SHAREBOX_HOSTNAME') or 'sharebox.lan'),
        ('ipv4', d.getVar('SHAREBOX_IPV4') or '192.168.77.1/24'),
        ('engine', ''),
        ('updates', d.getVar('SHAREBOX_UPDATES') or '1'),
        ('version', d.getVar('DISTRO_VERSION') or ''),
    ]
    path = d.expand('${D}${nonarch_libdir}/sharebox/defaults.conf')
    with open(path, 'w', encoding='utf-8') as f:
        f.write('# ShareBox build time defaults (generated, do not edit)\n')
        f.write('# Override at run time in /data/config/sharebox.conf\n')
        for k, v in items:
            if '\n' in v or '\r' in v:
                bb.fatal("SHAREBOX variable for '%s' contains a newline" % k)
            f.write('%s=%s\n' % (k, v))
    os.chmod(path, 0o644)
}
sharebox_write_defaults[vardeps] += "SHAREBOX_SSID SHAREBOX_LANG SHAREBOX_COUNTRY SHAREBOX_CHANNEL SHAREBOX_5GHZ SHAREBOX_UPLOAD_MAX SHAREBOX_CAPTIVE_MODE SHAREBOX_HOSTNAME SHAREBOX_IPV4 SHAREBOX_UPDATES DISTRO_VERSION"
do_install[postfuncs] += "sharebox_write_defaults"

do_install() {
    install -d ${D}${sbindir} ${D}${nonarch_libdir}/sharebox/setup.d \
        ${D}${nonarch_libdir}/sharebox/cgi-bin ${D}${datadir}/sharebox \
        ${D}${systemd_system_unitdir} ${D}${nonarch_libdir}/tmpfiles.d \
        ${D}${nonarch_libdir}/sysctl.d ${D}${nonarch_libdir}/systemd/network

    install -m 0755 ${S}/sharebox-setup ${D}${sbindir}/sharebox-setup
    install -m 0644 ${S}/sharebox-setup.service ${D}${systemd_system_unitdir}/

    install -m 0644 ${S}/tmpfiles-sharebox.conf ${D}${nonarch_libdir}/tmpfiles.d/sharebox.conf
    install -m 0644 ${S}/tmpfiles-sharebox-status.conf ${D}${nonarch_libdir}/tmpfiles.d/sharebox-status.conf
    install -m 0644 ${S}/tmpfiles-sharebox-devaccess.conf ${D}${nonarch_libdir}/tmpfiles.d/sharebox-devaccess.conf
    install -m 0644 ${S}/90-sharebox.conf ${D}${nonarch_libdir}/sysctl.d/90-sharebox.conf
    sed -e 's#@SHAREBOX_IPV4@#${SHAREBOX_IPV4}#' ${S}/10-wlan0.network.in \
        > ${D}${nonarch_libdir}/systemd/network/10-wlan0.network
    chmod 0644 ${D}${nonarch_libdir}/systemd/network/10-wlan0.network

    # /status CGI
    install -m 0755 ${S}/sharebox-status.cgi ${D}${nonarch_libdir}/sharebox/cgi-bin/status

    # Translations (data only)
    install -d ${D}${datadir}/sharebox/i18n
    for f in ${S}/i18n/*; do
        if [ -f "$f" ]; then install -m 0644 "$f" ${D}${datadir}/sharebox/i18n/; fi
    done

    # Pages: docroot gets the final pages, templates/ the CGI templates, and
    # each engine gets its own rendered home page (index-<engine>.html).
    www=${D}${datadir}/sharebox/www
    tpl=${D}${datadir}/sharebox/templates
    install -d $www $tpl
    if [ -f ${S}/www/style.css ]; then install -m 0644 ${S}/www/style.css $www/; fi
    for dir in ${S}/www/*/; do
        lang=$(basename $dir)
        install -d $www/$lang $tpl/$lang
        for f in $dir*; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            case $name in
                status*) install -m 0644 "$f" $tpl/$lang/ ;;
                engine-*.html|index.html|index.html.in) ;;
                *) install -m 0644 "$f" $www/$lang/ ;;
            esac
        done
        [ -f $dir/index.html.in ] || continue
        for engine in ${SHAREBOX_ENGINES}; do
            frag=$dir/engine-$engine.html
            [ -f $frag ] || frag=${S}/www/en/engine-$engine.html
            [ -f $frag ] || frag=/dev/null
            if [ "${SHAREBOX_UPLOAD_MAX}" = 0 ]; then
                sed -e /optional-upload/d $frag > ${B}/cards.html
            else
                cat $frag > ${B}/cards.html
            fi
            sed -e "/^[[:space:]]*@@ENGINE_LINKS@@[[:space:]]*\$/{
r ${B}/cards.html
d
}" $dir/index.html.in > $www/$lang/index-$engine.html
            chmod 0644 $www/$lang/index-$engine.html
        done
    done
    rm -f ${B}/cards.html
    # "/" outside lighttpd's language negotiation (engines serving port 80)
    if [ ! -f $www/index.html ]; then
        printf '<!DOCTYPE html>\n<html lang="en"><head><meta charset="utf-8"><title>ShareBox</title>\n<meta http-equiv="refresh" content="0; url=/en/"></head>\n<body><p><a href="/en/">ShareBox</a></p></body></html>\n' > $www/index.html
        chmod 0644 $www/index.html
    fi

    # Development profile
    install -d ${D}${sysconfdir}/nftables.d
    install -m 0644 ${S}/50-sharebox-dev.nft ${D}${sysconfdir}/nftables.d/
    install -d ${D}${ROOT_HOME}
    ln -sf /data/config/ssh ${D}${ROOT_HOME}/.ssh
}

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "--system --no-create-home --home-dir /data --shell /sbin/nologin --user-group sharebox"

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "sharebox-setup.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

PACKAGES = "${PN}-status ${PN}-devaccess ${@' '.join('${PN}-' + e for e in d.getVar('SHAREBOX_ENGINES').split())} ${PN}"

FILES:${PN} = " \
    ${sbindir}/sharebox-setup \
    ${systemd_system_unitdir}/sharebox-setup.service \
    ${nonarch_libdir}/sharebox/defaults.conf \
    ${nonarch_libdir}/sharebox/setup.d \
    ${nonarch_libdir}/tmpfiles.d/sharebox.conf \
    ${nonarch_libdir}/sysctl.d/90-sharebox.conf \
    ${nonarch_libdir}/systemd/network/10-wlan0.network \
    ${datadir}/sharebox/i18n \
    ${datadir}/sharebox/www \
"
FILES:${PN}-status = " \
    ${nonarch_libdir}/sharebox/cgi-bin \
    ${nonarch_libdir}/tmpfiles.d/sharebox-status.conf \
    ${datadir}/sharebox/templates \
"
FILES:${PN}-devaccess = " \
    ${sysconfdir}/nftables.d/50-sharebox-dev.nft \
    ${nonarch_libdir}/tmpfiles.d/sharebox-devaccess.conf \
    ${ROOT_HOME}/.ssh \
"
SUMMARY:${PN}-status = "ShareBox /status CGI and its templates"
SUMMARY:${PN}-devaccess = "ShareBox development access (SSH on wired interfaces only)"
RDEPENDS:${PN}-status = "${PN}"
RDEPENDS:${PN}-devaccess = "${PN} nftables"

python () {
    engines = d.getVar('SHAREBOX_ENGINES').split()
    for e in engines:
        pkg = 'sharebox-config-' + e
        d.setVar('FILES:' + pkg, '${datadir}/sharebox/www/*/index-%s.html' % e)
        d.setVar('SUMMARY:' + pkg, 'ShareBox home page for the %s engine' % e)
        d.setVar('RDEPENDS:' + pkg, 'sharebox-config')
        d.setVar('RCONFLICTS:' + pkg, ' '.join('sharebox-config-' + o for o in engines if o != e))
        d.setVar('ALLOW_EMPTY:' + pkg, '1')
        d.setVar('pkg_postinst:' + pkg, d.getVar('sharebox_engine_postinst').replace('@ENGINE@', e))
}

# Select the engine home page: <lang>/index.html -> index-<engine>.html,
# and record the engine in the runtime defaults. Runs at rootfs time.
sharebox_engine_postinst() {
    www=$D${datadir}/sharebox/www
    for page in $www/*/index-@ENGINE@.html; do
        [ -f "$page" ] || continue
        ln -sf index-@ENGINE@.html "$(dirname "$page")/index.html"
    done
    defaults=$D${nonarch_libdir}/sharebox/defaults.conf
    if [ -f "$defaults" ]; then
        sed -i -e 's/^engine=.*/engine=@ENGINE@/' "$defaults"
    fi
}
