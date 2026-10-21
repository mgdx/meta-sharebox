# RAUC keys

RAUC bundles are signed with an X.509 key. The device only trusts bundles
whose signing certificate chains up to the CA certificate installed in the
image (the "keyring", `/usr/lib/rauc/<keyring file>`). The keyring is the only
cryptographic material shipped in a ShareBox image.

## Development keys (`dev/`)

**These keys are public. Never ship a device signed with them.** Anybody can
build a bundle that a development-keyed box will accept.

| File | Role | In the image |
| --- | --- | --- |
| `dev/ca.cert.pem` | development CA, keyring | yes |
| `dev/development-1.cert.pem` | signing certificate | no |
| `dev/development-1.key.pem` | signing private key | no |

They were generated with `scripts/rauc-gen-keys.sh`. The CA private key was
deleted; regenerate the whole set if you need more signing certificates.

They are used by default (weak `??=` defaults in
`recipes-support/rauc/rauc-conf.bbappend` and
`recipes-core/bundles/sharebox-bundle.inc`). Building a bundle with them for
the `sharebox` (production) distro prints a warning.

## Production keys

1. On an offline machine: `scripts/rauc-gen-keys.sh /secure/sharebox-keys "My Org"`.
2. Keep `ca.key.pem` offline. Keep `signing.key.pem` in an HSM or an encrypted
   store that only the release machine can read. Do not commit them and do not
   put them in the CI cache.
3. Point the build at them, in `local.conf` or in a kas file that is not
   committed:

   ```
   RAUC_KEYRING_FILE = "/secure/sharebox-keys/ca.cert.pem"
   RAUC_CERT_FILE = "/secure/sharebox-keys/signing.cert.pem"
   RAUC_KEY_FILE = "/secure/sharebox-keys/signing.key.pem"
   ```

   `RAUC_KEY_FILE` may also be a PKCS#11 URI (`pkcs11:token=...;object=...`),
   see the RAUC documentation.

A box only accepts bundles signed under the keyring it was built with:
switching from development to production keys requires a reflash (or one
last bundle signed with the development key that installs an image carrying
the production keyring).
