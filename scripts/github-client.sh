#!/usr/bin/env bash

set -euo pipefail

operation=${1:-}
if [[ -z "$operation" ]]; then
  printf 'Usage: %s OPERATION [ARGUMENT...]\n' "${0##*/}" >&2
  exit 2
fi
shift

case "$operation" in
  latest-upstream-release)
    repository=${1:?upstream repository is required}
    gh api "repos/$repository/releases/latest"
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
  open-issue-number)
    repository=${1:?distribution repository is required}
    title=${2:?issue title is required}
    gh issue list \
      --repo "$repository" \
      --state open \
      --limit 100 \
      --json number,title |
      jq -r --arg title "$title" \
        'map(select(.title == $title)) | first | .number // empty'
    ;;
  create-issue)
    repository=${1:?distribution repository is required}
    title=${2:?issue title is required}
    body_file=${3:?issue body file is required}
    gh issue create \
      --repo "$repository" \
      --title "$title" \
      --body-file "$body_file" >/dev/null
    ;;
  comment-on-issue)
    repository=${1:?distribution repository is required}
    issue_number=${2:?issue number is required}
    body_file=${3:?comment body file is required}
    gh issue comment "$issue_number" \
      --repo "$repository" \
      --body-file "$body_file" >/dev/null
    ;;
  close-issue)
    repository=${1:?distribution repository is required}
    issue_number=${2:?issue number is required}
    body_file=${3:?closing comment body file is required}
    gh issue comment "$issue_number" \
      --repo "$repository" \
      --body-file "$body_file" >/dev/null
    gh issue close "$issue_number" \
      --repo "$repository" \
      --reason completed >/dev/null
    ;;
  *)
    printf 'Unsupported GitHub operation: %s\n' "$operation" >&2
    exit 2
    ;;
esac
