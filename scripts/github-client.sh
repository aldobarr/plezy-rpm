#!/usr/bin/env bash

set -euo pipefail

operation=${1:-}
if [[ -z "$operation" ]]; then
  printf 'Usage: %s OPERATION [ARGUMENT...]\n' "${0##*/}" >&2
  exit 2
fi
shift

case "$operation" in
  mirror-release-count)
    repository=${1:?distribution repository is required}
    gh api "repos/$repository/releases?per_page=1" | jq 'length'
    ;;
  latest-upstream-release)
    repository=${1:?upstream repository is required}
    gh api "repos/$repository/releases/latest"
    ;;
  all-upstream-releases)
    repository=${1:?upstream repository is required}
    gh api --paginate --slurp "repos/$repository/releases?per_page=100"
    ;;
  mirror-release-exists)
    repository=${1:?distribution repository is required}
    tag=${2:?release tag is required}
    gh release view "$tag" --repo "$repository" >/dev/null
    ;;
  create-mirror-release)
    repository=${1:?distribution repository is required}
    tag=${2:?release tag is required}
    title=${3:?release title is required}
    body_file=${4:?release body file is required}
    shift 4
    gh release create "$tag" \
      --repo "$repository" \
      --title "$title" \
      --notes-file "$body_file" \
      "$@"
    ;;
  all-mirror-releases)
    repository=${1:?distribution repository is required}
    gh api --paginate --slurp "repos/$repository/releases?per_page=100"
    ;;
  download-mirror-asset)
    repository=${1:?distribution repository is required}
    tag=${2:?release tag is required}
    asset_name=${3:?release asset name is required}
    destination=${4:?destination directory is required}
    gh release download "$tag" \
      --repo "$repository" \
      --pattern "$asset_name" \
      --dir "$destination"
    ;;
  *)
    printf 'Unsupported GitHub operation: %s\n' "$operation" >&2
    exit 2
    ;;
esac
