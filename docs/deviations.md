# Deviations from the specification

Choices made during implementation that differ from
"Spécification meta-sharebox". Each lot adds its own section.

## Base system (core lot)

### UART enabled whenever U-Boot is used

The specification asks for `ENABLE_UART = "0"` in production. With
`RPI_USE_U_BOOT = "1"` (required by RAUC), meta-raspberrypi's `rpi-config`
refuses `ENABLE_UART = "0"` on the Zero W, Pi 3, Pi 4 and 64-bit boards
(`rpi_0_w`, `rpi_3_32b`, `rpi_4_32b`, `rpi_arm64` U-Boot configurations):
U-Boot needs the UART to operate.

So the UART is electrically enabled (`enable_uart=1` in `config.txt`)
whenever U-Boot is used, which means always when `SHAREBOX_UPDATES = "1"`.
In production (`SHAREBOX_DEV = "0"`), nothing is attached to it:

- `CMDLINE_SERIAL = ""`: no `console=serial0` on the kernel command line.
  U-Boot passes the firmware's `cmdline.txt` bootargs through, so the kernel
  has no serial console either way.
- `SERIAL_CONSOLES = ""`: no serial getty (and the systemd getty generator
  has no serial console to attach to).
- U-Boot itself still prints on the UART and honours its boot delay; an
  attacker with physical access to the header is out of the threat model
  (physical access also gives the SD card).

With `SHAREBOX_UPDATES = "0"`, U-Boot is not used and `ENABLE_UART = "0"`.
The dev profile (`sharebox-dev`) enables the UART, the serial console and its
login.

### dnsmasq `bind-dynamic`

`bind-dynamic` instead of `bind-interfaces`: same listening set (wlan0 and
lo) but dnsmasq does not fail when wlan0 gets its address after it starts.

### PCI kept in the kernel

The specification disables PCI except on Pi 5. The Pi 4 (and CM4) USB
controller is a PCIe device, so PCI stays enabled on every machine.

### /status client count

`/status` counts the devices seen on wlan0 in the ARP table instead of
calling `hostapd_cli all_sta`: giving the web server access to the hostapd
control socket would let it reconfigure the access point.

### Kernel modules and module signing

The image still installs `kernel-modules` (from meta-raspberrypi's
`MACHINE_EXTRA_RRECOMMENDS`); trimming it to an explicit module list is a
footprint task for later. Module signing (`module.sig_enforce=1`) is not
configured yet.

### CVE databases and SPDX sources on developer builds

`sbom-cve-check` downloads the CVE databases (several GB) and
`SPDX_INCLUDE_SOURCES = "1"` makes SBOMs large. Both are on by default;
developer builds may set `SHAREBOX_CVE_CHECK = "0"` and
`SPDX_INCLUDE_SOURCES = "0"` in `local.conf`.
