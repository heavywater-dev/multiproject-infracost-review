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

format_diff_markdown() {
  local json_file="$1"
  local result=""

  local projects_count=$(jq -r '.projects | length // 0' "$json_file")
  
  if [[ "$projects_count" -gt 0 ]]; then
    while IFS= read -r project_data; do
      local project_name=$(echo "$project_data" | jq -r '.name // "Unknown Project"')
      local resources_data=$(echo "$project_data" | jq -r '.diff.resources // []')
      local resources_count=$(echo "$resources_data" | jq -r 'length // 0')
      
      if [[ "$resources_count" -gt 0 ]]; then
        local resources_table=""
        while IFS= read -r resource; do
          local res_name=$(echo "$resource" | jq -r '.name // "Unknown"')
          local res_type=$(echo "$resource" | jq -r '.resourceType // "Unknown"')
          local cost_change=$(echo "$resource" | jq -r '
            if .monthlyCostDiff and (.monthlyCostDiff | tonumber) != 0 then
              ("$" + (.monthlyCostDiff | tostring) + "/month")
            else
              "No change"
            end
          ')
          resources_table+=$(format_resource_row "$res_name" "$res_type" "$cost_change")$'\n'
        done < <(echo "$resources_data" | jq -c '.[]')
        
        local project_total=$(echo "$project_data" | jq -r '
          if .diff.totalMonthlyCost and (.diff.totalMonthlyCost | tonumber) != 0 then
            ("$" + (.diff.totalMonthlyCost | tostring) + "/month")
          else
            "$0/month"
          end
        ')
        
        result+=$(format_project_section "$project_name" "true" "$resources_table" "$project_total")$'\n'
      else
        result+=$(format_project_section "$project_name" "false" "" "")$'\n'
      fi
    done < <(jq -c '.projects[]' "$json_file")
  else
    local total_cost=$(jq -r '
      if .diffTotalMonthlyCost then
        "**Total monthly cost change:** $" + (.diffTotalMonthlyCost | tostring) + "/month"
      elif .totalMonthlyCost then
        "**Total monthly cost:** $" + (.totalMonthlyCost | tostring) + "/month"
      else
        "*(no diff content)*"
      end
    ' "$json_file")
    result="$total_cost"
  fi
  
  echo "$result"
}

DIFF_MD=$(format_diff_markdown "$DIFF_FILE")

TOTAL_MD_PART=$(jq -r '.metadata.totalCostComment // ""' "$DIFF_FILE")

TEMPLATE_FILE="$SCRIPT_DIR/comment/comment-template.md"

TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")
COMMENT_BODY=$(replace_template_vars "$TEMPLATE_CONTENT" "$TOTAL_MD_PART" "$DIFF_MD")

echo "Posting new comment..."

curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -X POST \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" \
  -d "{\"body\": $(echo "$COMMENT_BODY" | jq -Rs .)}"

echo "Custom Infracost comment posted."
