#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/comment/template-helpers.sh"

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

echo "Fetching existing comments..."

COMMENTS_JSON=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments")

COMMENT_ID=$(echo "$COMMENTS_JSON" | jq -r \
  --arg tag "$COMMENT_TAG" '
    .[] | select(.body | contains($tag)) | .id
  ')

if [[ -n "$COMMENT_ID" && "$COMMENT_ID" != "null" ]]; then
  echo "Deleting old comment (#$COMMENT_ID)..."
  curl -s -X DELETE \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/issues/comments/$COMMENT_ID"
fi

echo "Building cost summary..."

format_summary() {
  jq -r '
    def num(x): if x == null then "0" else x end;

    "• Main branch (before): $" + (num(.pastTotalMonthlyCost) | tostring) + " / month\n" +
    "• This PR (after): $" + (num(.totalMonthlyCost) | tostring) + " / month\n" +
    "• Monthly diff (after−before): $" + (num(.diffTotalMonthlyCost) | tostring) + " / month"
  ' "$1"
}

format_diff_markdown() {
  local json="$1"
  local result=""

  jq -c '.projects[]' "$json" | while read -r project; do
    local name
    name=$(echo "$project" | jq -r '.name')

    result+="### $name"$'\n'

    local resources
    resources=$(echo "$project" | jq -c '.diff.resources[]?')

    if [[ -z "$resources" ]]; then
      result+="No cost changes"$'\n\n'
      continue
    fi

    echo "$project" | jq -c '.diff.resources[]' | while read -r r; do
      local res_name res_type diff
      res_name=$(echo "$r" | jq -r '.name')
      res_type=$(echo "$r" | jq -r '.resourceType')
      diff=$(echo "$r" | jq -r '.monthlyCostDiff')

      [[ "$diff" == "0" ]] && continue
      result+="- $res_type.$res_name: \$${diff} / month"$'\n'
    done

    local total
    total=$(echo "$project" | jq -r '.diff.totalMonthlyCost // 0')

    result+=$'\n'"Total: \$${total} / month"$'\n\n'
  done

  echo "$result"
}

SUMMARY_MD=$(format_summary "$DIFF_FILE")
DIFF_MD=$(format_diff_markdown "$DIFF_FILE")

TEMPLATE_FILE="$SCRIPT_DIR/comment/comment-template.md"
TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")

COMMENT_BODY=$(replace_template_vars "$TEMPLATE_CONTENT" "$SUMMARY_MD" "$DIFF_MD")

echo "Posting comment..."

curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -X POST \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" \
  -d "{\"body\": $(echo "$COMMENT_BODY" | jq -Rs .)}"

echo "Infracost comment posted."
