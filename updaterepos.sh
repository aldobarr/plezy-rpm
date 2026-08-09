#!/usr/bin/env bash

# Adapted from VSCodium's vscodium-deb-rpm-repo/updaterepos.sh for the
# release-backed Plezy RPM repository.

set -euo pipefail

mode=${1:-}
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
upstream_repository=${UPSTREAM_REPOSITORY:-edde746/plezy}
distribution_repository=${DISTRIBUTION_REPOSITORY:-${GITHUB_REPOSITORY:-aldobarr/plezy-rpm}}
public_key_file=${PUBLIC_KEY_FILE:-$project_root/RPM-GPG-KEY-plezy-rpm}
release_asset_base_url=${RELEASE_ASSET_BASE_URL:-https://github.com/$distribution_repository/releases/download/}
github_client=${GITHUB_CLIENT:-$project_root/scripts/github-client.sh}
work_directory="$(mktemp -d)"
signing_keyring="$work_directory/keyring"
signing_fingerprint=''
created_release=0

cleanup() {
  rm -rf "$work_directory"
}
trap cleanup EXIT

case "$mode" in
  scheduled | backfill) ;;
  *)
    printf 'Usage: %s scheduled|backfill\n' "${0##*/}" >&2
    exit 2
    ;;
esac

release_is_eligible() {
  jq -e '
    .draft == false and
    .prerelease == false and
    .published_at != null and
    ([.assets[].name] | index("plezy-linux-x64.rpm")) != null and
    ([.assets[].name] | index("plezy-linux-arm64.rpm")) != null
  ' >/dev/null
}

load_signing_key() {
  local public_fingerprint

  if [[ -n "$signing_fingerprint" ]]; then
    return
  fi
  if [[ -z "${RPM_SIGNING_PRIVATE_KEY:-}" ]]; then
    printf 'RPM_SIGNING_PRIVATE_KEY is required to publish a release.\n' >&2
    exit 1
  fi
  if [[ ! -s "$public_key_file" ]]; then
    printf 'Public signing key not found: %s\n' "$public_key_file" >&2
    exit 1
  fi

  mkdir -p "$signing_keyring"
  chmod 700 "$signing_keyring"
  printf '%s\n' "$RPM_SIGNING_PRIVATE_KEY" |
    gpg --homedir "$signing_keyring" --batch --import >/dev/null 2>&1

  signing_fingerprint="$(
    gpg --homedir "$signing_keyring" --batch --with-colons \
      --list-secret-keys --fingerprint |
      awk -F: '$1 == "sec" { primary = 1; next } primary && $1 == "fpr" { print $10; exit }'
  )"
  public_fingerprint="$(
    gpg --homedir "$signing_keyring" --batch --with-colons \
      --show-keys --fingerprint "$public_key_file" |
      awk -F: '$1 == "pub" { primary = 1; next } primary && $1 == "fpr" { print $10; exit }'
  )"

  if [[ -z "$signing_fingerprint" || "$signing_fingerprint" != "$public_fingerprint" ]]; then
    printf 'The private signing key does not match %s.\n' "$public_key_file" >&2
    exit 1
  fi
}

sign_rpm() {
  local rpm_file=$1
  local signing_command='rpm'

  if command -v rpmsign >/dev/null 2>&1; then
    signing_command='rpmsign'
  fi

  "$signing_command" \
    --define "_gpg_name $signing_fingerprint" \
    --define "_gpg_path $signing_keyring" \
    --define "__gpg /usr/bin/gpg" \
    --addsign "$rpm_file"
}

mirror_release() {
  local release_json=$1
  local tag title body_file release_directory asset_name asset_url
  local -a signed_assets=()

  if ! release_is_eligible <<<"$release_json"; then
    return
  fi

  tag="$(jq -r '.tag_name' <<<"$release_json")"
  if "$github_client" mirror-release-exists \
    "$distribution_repository" "$tag" >/dev/null 2>&1; then
    return
  fi

  load_signing_key
  release_directory="$work_directory/releases/$tag"
  body_file="$release_directory/release-body.md"
  mkdir -p "$release_directory"

  for asset_name in plezy-linux-x64.rpm plezy-linux-arm64.rpm; do
    asset_url="$(
      jq -r --arg name "$asset_name" \
        '.assets[] | select(.name == $name) | .browser_download_url' \
        <<<"$release_json"
    )"
    curl --fail --silent --show-error --location \
      "$asset_url" --output "$release_directory/$asset_name"
    sign_rpm "$release_directory/$asset_name"
    signed_assets+=("$release_directory/$asset_name")
  done

  title="$(jq -r '.name // ""' <<<"$release_json")"
  jq -j '.body // ""' <<<"$release_json" >"$body_file"
  "$github_client" create-mirror-release \
    "$distribution_repository" \
    "$tag" \
    "$title" \
    "$body_file" \
    "${signed_assets[@]}"
  created_release=1
}

publish_repository() {
  local output_directory=${PAGES_OUTPUT_DIR:-}
  local package_directory="$work_directory/packages"
  local prepared_pages="$work_directory/pages"
  local mirror_release_pages tag release_directory asset_name

  if [[ -z "$output_directory" ]]; then
    printf 'PAGES_OUTPUT_DIR is required when repository metadata is published.\n' >&2
    exit 1
  fi
  if [[ "$output_directory" == '/' ]]; then
    printf 'Refusing to use / as PAGES_OUTPUT_DIR.\n' >&2
    exit 1
  fi
  if [[ -d "$output_directory" ]] &&
    find "$output_directory" -mindepth 1 -print -quit | grep -q .; then
    printf 'PAGES_OUTPUT_DIR must be empty: %s\n' "$output_directory" >&2
    exit 1
  fi

  load_signing_key
  mkdir -p "$package_directory" "$prepared_pages"

  mirror_release_pages="$(
    "$github_client" all-mirror-releases "$distribution_repository"
  )"
  mapfile -t mirror_releases < <(jq -c 'add | reverse[]' <<<"$mirror_release_pages")
  if [[ ${#mirror_releases[@]} -eq 0 ]]; then
    printf 'Cannot publish repository metadata without Mirror Releases.\n' >&2
    exit 1
  fi

  for mirror_release_json in "${mirror_releases[@]}"; do
    tag="$(jq -r '.tag_name' <<<"$mirror_release_json")"
    release_directory="$package_directory/$tag"
    mkdir -p "$release_directory"
    for asset_name in plezy-linux-x64.rpm plezy-linux-arm64.rpm; do
      "$github_client" download-mirror-asset \
        "$distribution_repository" \
        "$tag" \
        "$asset_name" \
        "$release_directory"
    done
  done

  createrepo_c \
    --baseurl "${release_asset_base_url%/}/" \
    --outputdir "$prepared_pages" \
    "$package_directory" >/dev/null

  cp "$project_root/plezy.repo" "$prepared_pages/plezy.repo"
  cp "$public_key_file" "$prepared_pages/RPM-GPG-KEY-plezy-rpm"
  : >"$prepared_pages/.nojekyll"

  gpg --homedir "$signing_keyring" \
    --batch \
    --yes \
    --local-user "$signing_fingerprint" \
    --armor \
    --detach-sign \
    --output "$prepared_pages/repodata/repomd.xml.asc" \
    "$prepared_pages/repodata/repomd.xml"
  gpg --homedir "$signing_keyring" --batch \
    --verify "$prepared_pages/repodata/repomd.xml.asc" \
    "$prepared_pages/repodata/repomd.xml" >/dev/null 2>&1

  mkdir -p "$output_directory"
  cp -a "$prepared_pages/." "$output_directory/"
}

if [[ "$mode" == 'scheduled' ]]; then
  release_count="$(
    "$github_client" mirror-release-count "$distribution_repository"
  )"
  if [[ "$release_count" -eq 0 ]]; then
    printf 'Scheduled Sync requires an initialized mirror. Run Backfill Sync manually first.\n' >&2
    exit 1
  fi

  latest_release="$(
    "$github_client" latest-upstream-release "$upstream_repository"
  )"
  mirror_release "$latest_release"
else
  upstream_release_pages="$(
    "$github_client" all-upstream-releases "$upstream_repository"
  )"
  mapfile -t upstream_releases < <(jq -c 'add | reverse[]' <<<"$upstream_release_pages")
  for upstream_release in "${upstream_releases[@]}"; do
    mirror_release "$upstream_release"
  done
fi

if [[ "$mode" == 'backfill' || $created_release -eq 1 ]]; then
  publish_repository
fi
