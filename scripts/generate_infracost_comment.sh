#!/bin/bash
set -e

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="$2"; shift 2 ;;
    --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
    --pull-request) PR_NUMBER="$2"; shift 2 ;;
    --diff-file) DIFF_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

COMMENT_TAG="<!-- infracost-total-comment -->"

echo "Fetching existing comments to delete old one..."

COMMENTS_JSON=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments")

COMMENT_ID=$(echo "$COMMENTS_JSON" | jq -r \
  --arg tag "$COMMENT_TAG" '
    .[] | select(.body | contains($tag)) | .id
  ')

if [[ "$COMMENT_ID" != "" && "$COMMENT_ID" != "null" ]]; then
  echo "Old comment found (#$COMMENT_ID), deleting..."

  curl -s -X DELETE \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/issues/comments/$COMMENT_ID"

  echo "Old comment deleted"
else
  echo "No old comment to delete"
fi

echo "Extracting data from diff JSON: $DIFF_FILE"

DIFF_MD=$(jq -r '.diff // ""' "$DIFF_FILE")

TOTAL_MD_PART=$(jq -r '.metadata.totalCostComment // ""' "$DIFF_FILE")

if [[ "$DIFF_MD" == "" ]]; then
  DIFF_MD="*(no diff content)*"
fi

read -r -d '' COMMENT_BODY << EOF || true
$COMMENT_TAG
# 💰 Infrastructure Cost Overview

$TOTAL_MD_PART

---

## Cost diff
$DIFF_MD

---

_This comment will auto-update when code changes._
EOF

echo "Posting new comment..."

curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -X POST \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" \
  -d "{\"body\": $(echo "$COMMENT_BODY" | jq -Rs .)}"

echo "Custom Infracost comment posted."
