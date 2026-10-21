# Kernel hardening

ShareBox uses the meta-raspberrypi kernel (`linux-raspberrypi`, 6.18 in
Wrynose) with the bcm27xx defconfig of each machine, plus three
configuration fragments from `recipes-kernel/linux/`, merged by
kernel-yocto (`linux-raspberrypi_%.bbappend`):

| Fragment | Purpose |
| --- | --- |
| `files/sharebox.cfg` | features: nftables, erofs, overlayfs, USB filesystems, dm-verity; removal of Bluetooth, sound, DRM, media, NFC, CAN |
| `files/sharebox-security.cfg` | hardening, derived from linux-yocto `features/security/security.cfg` |
| `sharebox-storage/sharebox-storage.cfg` | options needed before modules can load (no initramfs): erofs, overlayfs, ext4, vfat, loop, dm-verity, squashfs |

Run time settings complete the kernel configuration: the sysctl file
`/usr/lib/sysctl.d/90-sharebox.conf` (package `sharebox-config`) and the
kernel command line (`cmdline.txt`, `panic=10`).

## Hardening options set by the layer

| Option | Value | Reason |
| --- | --- | --- |
| `CONFIG_SECURITY`, `CONFIG_SECURITYFS` | y | LSM framework |
| `CONFIG_SECURITY_LANDLOCK` | y | unprivileged sandboxing available to services |
| `CONFIG_SECURITY_YAMA` | y | ptrace restrictions (`kernel.yama.ptrace_scope = 1`) |
| `CONFIG_SECURITY_LOCKDOWN_LSM` | y | lockdown LSM available (see deviations: not enforced) |
| `CONFIG_LSM` | `landlock,lockdown,yama,integrity,bpf` | LSM order |
| `CONFIG_SECCOMP`, `CONFIG_SECCOMP_FILTER` | y | systemd `SystemCallFilter=` of every unit |
| `CONFIG_STRICT_KERNEL_RWX`, `CONFIG_STRICT_MODULE_RWX` | y | no writable and executable kernel memory |
| `CONFIG_RANDOMIZE_BASE` | y | KASLR (64-bit machines) |
| `CONFIG_STACKPROTECTOR`, `CONFIG_STACKPROTECTOR_STRONG` | y | stack canaries |
| `CONFIG_VMAP_STACK` | y | guard pages around kernel stacks |
| `CONFIG_SLAB_FREELIST_HARDENED`, `CONFIG_SLAB_FREELIST_RANDOM` | y | heap metadata hardening |
| `CONFIG_SHUFFLE_PAGE_ALLOCATOR` | y | page allocator randomisation |
| `CONFIG_HARDENED_USERCOPY` | y | bounds checks on user copies |
| `CONFIG_FORTIFY_SOURCE` | y | compile time and run time buffer checks |
| `CONFIG_INIT_ON_ALLOC_DEFAULT_ON` | y | zero memory on allocation |
| `CONFIG_BPF_UNPRIV_DEFAULT_OFF` | y | no unprivileged BPF |
| `CONFIG_BPF_JIT_ALWAYS_ON` | y | no BPF interpreter (Spectre gadgets) |
| `CONFIG_DEVMEM`, `CONFIG_DEVPORT`, `CONFIG_PROC_KCORE` | n | no raw access to physical or kernel memory |
| `CONFIG_KEXEC` | n | no kernel replacement at run time |
| `CONFIG_LEGACY_TIOCSTI` | n | no terminal input injection |
| `CONFIG_USERFAULTFD` | n | removes a common exploitation primitive |
| `CONFIG_SCHED_STACK_END_CHECK`, `CONFIG_DEBUG_LIST`, `CONFIG_BUG_ON_DATA_CORRUPTION` | y | detect corruption early and stop |

Attack surface reduction (`sharebox.cfg`): no Bluetooth (`CONFIG_BT`), no
sound, no DRM, no media/V4L2, no joystick or touchscreen input, no NFC, no
CAN, no amateur radio.

Run time (`90-sharebox.conf`): `kernel.kptr_restrict = 2`,
`kernel.dmesg_restrict = 1`, `kernel.unprivileged_bpf_disabled = 1`,
`kernel.kexec_load_disabled = 1`, `kernel.yama.ptrace_scope = 1`,
`net.core.bpf_jit_harden = 2`, `fs.protected_{hardlinks,symlinks,fifos,regular} = 1`,
`fs.suid_dumpable = 0`, no IP forwarding, reverse path filtering, no ICMP
redirects, no source routing, no IPv6 router advertisements, SYN cookies.

## Deviations from the specification and justification

| Item | Specification | Layer | Justification |
| --- | --- | --- | --- |
| Module signing | `CONFIG_MODULES` kept, `module.sig_enforce=1`, modules signed at build | not configured yet | meta-raspberrypi does not set up module signing; to do in a later version. Meanwhile the rootfs is read-only (modules can only come from the image) and every service unit has `ProtectKernelModules=yes`. |
| PCI | disabled except on Pi 5 | enabled on every machine | the Pi 4 and CM4 USB controller is a PCIe device (`docs/deviations.md`) |
| Kernel lockdown | not specified | LSM built, mode not enforced (no `lockdown=` on the command line) | `lockdown=integrity` would also require signed modules; to evaluate with module signing |
| `CONFIG_RANDOMIZE_BASE`, `CONFIG_VMAP_STACK`, `CONFIG_BPF_JIT_ALWAYS_ON` on the Pi Zero W | set | may be dropped by Kconfig on `raspberrypi0-wifi` (32-bit ARMv6) where the architecture does not support them | check the `do_kernel_configcheck` warnings of that machine |
| `CONFIG_DM_VERITY` for the rootfs slots | `SHAREBOX_VERITY` option | built in, but `SHAREBOX_VERITY` is not implemented; dm-verity is used only for RAUC verity bundles | needs an initramfs or U-Boot support; later option |

## Options not set by the layer

Their value comes from the meta-raspberrypi defconfig and has not been
reviewed yet. They are typical findings of `kernel-hardening-checker` and
will be decided (enabled, or listed here with a reason) once its report is
available:

- `CONFIG_INIT_ON_FREE_DEFAULT_ON` (cost on small machines to measure),
- `CONFIG_RANDOMIZE_KSTACK_OFFSET_DEFAULT`, `CONFIG_ZERO_CALL_USED_REGS`,
- `CONFIG_MODULE_SIG*`, `CONFIG_STATIC_USERMODEHELPER`,
- arm64 specific: `CONFIG_ARM64_SW_TTBR0_PAN`, `CONFIG_UNMAP_KERNEL_AT_EL0`,
  `CONFIG_ARM64_PTR_AUTH`, `CONFIG_ARM64_BTI` (pointer authentication and
  BTI are not implemented by the Cortex-A53/A72/A76 cores of the Pi),
- debug features left on by the defconfig (`CONFIG_DEBUG_FS`, ...).

## Verification

- `kernel-hardening-checker` (<https://github.com/a13xp0p0v/kernel-hardening-checker>)
  is to be run in CI on the `.config` produced for each machine. The
  `build` workflow (`.github/workflows/build.yml`, self-hosted runner)
  keeps the kernel work directory and runs it, and uploads the report as an
  artefact. The GitHub-hosted CI cannot build the kernel (disk and time
  limits).
- By hand: keep the kernel work directory with
  `RM_WORK_EXCLUDE += "linux-raspberrypi"` (for example in `kas/local.yml`,
  see the README), then

  ```sh
  kas build kas/rpi4-64.yml:kas/local.yml --target linux-raspberrypi
  config=$(find build/tmp/work -path '*linux-raspberrypi*' -name .config | head -n 1)
  kernel-hardening-checker -c "$config" -m show_fail
  ```

  Add `-l <file>` with a copy of the box's `/proc/cmdline` to check the
  command line too.
- On the box (dev image): `sysctl -a`, `cat /sys/kernel/security/lsm`,
  `cat /sys/kernel/security/lockdown`.

Each finding is either fixed in `sharebox-security.cfg` or added to the
deviation table above with its justification.
