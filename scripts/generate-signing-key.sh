#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s OUTPUT_DIRECTORY\n' "${0##*/}" >&2
  exit 2
fi

output_directory=$1
public_key="$output_directory/RPM-GPG-KEY-plezy-rpm"
private_key="$output_directory/RPM-SIGNING-PRIVATE-KEY.asc"
revocation_certificate="$output_directory/RPM-SIGNING-REVOCATION.rev"
keyring="$(mktemp -d)"

cleanup() {
  rm -rf "$keyring"
}

trap cleanup EXIT

for output_file in "$public_key" "$private_key" "$revocation_certificate"; do
  if [[ -e "$output_file" ]]; then
    printf 'Refusing to overwrite existing key material: %s\n' "$output_file" >&2
    exit 1
  fi
done

umask 077
mkdir -p "$output_directory"
chmod 700 "$keyring"

gpg --homedir "$keyring" \
  --batch \
  --pinentry-mode loopback \
  --passphrase '' \
  --quick-generate-key \
  'Plezy' rsa4096 sign 0 >/dev/null 2>&1

fingerprint="$(
  gpg --homedir "$keyring" --batch --with-colons \
    --list-secret-keys --fingerprint 2>/dev/null |
    awk -F: '$1 == "sec" { primary = 1; next } primary && $1 == "fpr" { print $10; exit }'
)"

if [[ -z "$fingerprint" ]]; then
  printf 'Could not determine the generated signing-key fingerprint.\n' >&2
  exit 1
fi

gpg --homedir "$keyring" --batch --armor \
  --export "$fingerprint" >"$public_key"
gpg --homedir "$keyring" --batch --armor \
  --export-secret-keys "$fingerprint" >"$private_key"
cp "$keyring/openpgp-revocs.d/$fingerprint.rev" "$revocation_certificate"

chmod 644 "$public_key"
chmod 600 "$private_key" "$revocation_certificate"

printf 'Generated Plezy RPM signing key %s\n' "$fingerprint"
printf 'Public key: %s\n' "$public_key"
printf 'Private key: %s\n' "$private_key"
printf 'Revocation certificate: %s\n' "$revocation_certificate"
