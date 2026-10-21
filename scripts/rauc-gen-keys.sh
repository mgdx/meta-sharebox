#!/bin/sh
# Generate a RAUC signing PKI for ShareBox: a CA certificate (the keyring that
# goes into the image) and one signing key/certificate pair issued by that CA.
#
# Usage: scripts/rauc-gen-keys.sh <output-dir> [<organisation>]
#
# The development keys shipped in files/rauc-keys/dev/ were created with
#   scripts/rauc-gen-keys.sh files/rauc-keys/dev "ShareBox Development"
# then ca.key.pem was deleted and signing.{key,cert}.pem were renamed to
# development-1.{key,cert}.pem.
#
# For production, run this on an offline machine, keep ca.key.pem and
# signing.key.pem out of the repository and the CI (HSM or encrypted storage),
# and point RAUC_KEY_FILE, RAUC_CERT_FILE and RAUC_KEYRING_FILE at the result
# (see files/rauc-keys/README.md).
#
# Inspired by meta-rauc scripts/openssl-ca.sh (MIT).
set -eu

out=${1:?usage: $0 <output-dir> [<organisation>]}
org=${2:-ShareBox}
days=${RAUC_KEYS_DAYS:-10950}

mkdir -p "$out"
cd "$out"
if [ -e ca.cert.pem ] || [ -e signing.key.pem ]; then
    echo "$out already contains keys, refusing to overwrite" >&2
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/ext.cnf" <<EOF
[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign

[ v3_leaf ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
EOF

umask 077
openssl req -new -newkey rsa:4096 -nodes -sha256 \
    -subj "/O=$org/CN=$org RAUC CA" \
    -keyout ca.key.pem -out "$work/ca.csr.pem"
openssl x509 -req -sha256 -days "$days" -in "$work/ca.csr.pem" \
    -signkey ca.key.pem -set_serial 1000 \
    -extfile "$work/ext.cnf" -extensions v3_ca -out ca.cert.pem

openssl req -new -newkey rsa:4096 -nodes -sha256 \
    -subj "/O=$org/CN=$org RAUC signing 1" \
    -keyout signing.key.pem -out "$work/signing.csr.pem"
openssl x509 -req -sha256 -days "$days" -in "$work/signing.csr.pem" \
    -CA ca.cert.pem -CAkey ca.key.pem -set_serial 1 \
    -extfile "$work/ext.cnf" -extensions v3_leaf -out signing.cert.pem

chmod 0644 ca.cert.pem signing.cert.pem
openssl verify -CAfile ca.cert.pem signing.cert.pem
echo "Keep ca.key.pem and signing.key.pem secret."
