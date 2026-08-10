#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]] || [[ "$1" != 'success' && "$1" != 'failure' ]]; then
  printf 'Usage: %s success|failure\n' "${0##*/}" >&2
  exit 2
fi

status=$1
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
github_client=${GITHUB_CLIENT:-$project_root/scripts/github-client.sh}
repository=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}
server_url=${GITHUB_SERVER_URL:-https://github.com}
run_id=${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}
run_url="${server_url%/}/$repository/actions/runs/$run_id"
issue_title='Automated RPM synchronization failed'
work_directory="$(mktemp -d)"
message_file="$work_directory/message.md"

cleanup() {
  rm -rf "$work_directory"
}

trap cleanup EXIT

issue_number="$(
  "$github_client" open-issue-number "$repository" "$issue_title"
)"

if [[ "$status" == 'failure' ]]; then
  if [[ -z "$issue_number" ]]; then
    printf 'The automated RPM synchronization workflow failed.\n\nFailed run: %s\n' "$run_url" >"$message_file"
    "$github_client" create-issue "$repository" "$issue_title" "$message_file"
  else
    printf 'The synchronization workflow failed again.\n\nFailed run: %s\n' "$run_url" >"$message_file"
    "$github_client" comment-on-issue "$repository" "$issue_number" "$message_file"
  fi
  exit 0
fi

if [[ -z "$issue_number" ]]; then
  exit 0
fi

printf 'The synchronization workflow succeeded.\n\nSuccessful run: %s\n' "$run_url" >"$message_file"
"$github_client" close-issue "$repository" "$issue_number" "$message_file"
