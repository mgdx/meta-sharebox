# ShareBox: smaller systemd. Kept: networkd (wlan0), tmpfiles, sysctl,
# sysusers, logind, udev, seccomp. Dropped: name resolution (dnsmasq answers
# clients, the box itself never resolves), time sync (offline), hostnamed,
# machined, coredump, backlight and desktop oriented services.
PACKAGECONFIG:remove = " \
    resolved nss-resolve \
    timesyncd timedated \
    hostnamed localed \
    machined nss-mymachines \
    coredump \
    backlight \
    vconsole \
    quotacheck \
    hibernate \
    binfmt \
    ima \
    idn \
"
