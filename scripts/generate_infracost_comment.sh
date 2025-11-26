#!/bin/bash
set -e

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="$2"; shift 2 ;;
    --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
    --pull-request) PR_NUMBER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "Generating standard diff comment..."

infracost comment github \
  --path=/tmp/infracost-diff.json \
  --repo="$REPO" \
  --github-token="$GITHUB_TOKEN" \
  --pull-request="$PR_NUMBER" \
  --behavior=delete-and-new
