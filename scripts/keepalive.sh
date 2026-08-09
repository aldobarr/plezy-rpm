#!/usr/bin/env bash

set -euo pipefail

keepalive_after_days=${KEEPALIVE_AFTER_DAYS:-45}

if [[ ! "$keepalive_after_days" =~ ^[0-9]+$ ]] || [[ "$keepalive_after_days" -eq 0 ]]; then
  printf 'KEEPALIVE_AFTER_DAYS must be a positive whole number.\n' >&2
  exit 2
fi

last_commit_epoch=$(git log -1 --format=%ct)
current_epoch=$(date -u +%s)
age_days=$(( (current_epoch - last_commit_epoch) / 86400 ))

if [[ "$age_days" -lt "$keepalive_after_days" ]]; then
  printf 'Latest default-branch commit is %s days old; no keepalive is needed.\n' "$age_days"
  exit 0
fi

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git commit --allow-empty --message 'chore: keep scheduled RPM sync active'
git push origin HEAD
