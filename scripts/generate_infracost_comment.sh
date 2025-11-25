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

echo "Standard comment created"

if [ "${SKIP_TOTAL_COST}" = "true" ]; then
  echo "Additional comment disabled via SKIP_TOTAL_COST=true"
  exit 0
fi

echo "Generating additional total cost information..."

if [ -f "/tmp/infracost-base.json" ] && [ -f "/tmp/infracost-pr.json" ]; then
  echo "Found cost data files"
  
  if ! command -v jq &> /dev/null; then
    echo "jq not installed, skipping additional comment"
    exit 0
  fi

  echo "Extracting cost data..."
  BASE_TOTAL=$(jq -r '.totalMonthlyCost // "0"' /tmp/infracost-base.json 2>/dev/null || echo "0")
  PR_TOTAL=$(jq -r '.totalMonthlyCost // "0"' /tmp/infracost-pr.json 2>/dev/null || echo "0")
  
  echo "Base cost: \$${BASE_TOTAL}/month"
  echo "PR cost: \$${PR_TOTAL}/month"
  
  BASE_BRANCH="${GITHUB_BASE_REF:-main}"
  
  BASE_PROJECTS=$(jq -r '.projects[]? | "• \(.name): $\(.breakdown.totalMonthlyCost // "0")"' /tmp/infracost-base.json 2>/dev/null | head -10 || echo "• No data")
  
  PR_PROJECTS=$(jq -r '.projects[]? | "• \(.name): $\(.breakdown.totalMonthlyCost // "0")"' /tmp/infracost-pr.json 2>/dev/null | head -10 || echo "• No data")
  
  read -r -d '' TOTAL_COMMENT << 'EOF' || true
---
## Total Infrastructure Cost

| | Cost |
|---|---|
| **Base branch (BASE_BRANCH_PLACEHOLDER)** | $BASE_TOTAL_PLACEHOLDER/month |
| **PR branch** | $PR_TOTAL_PLACEHOLDER/month |

<details>
<summary>Detailed project breakdown</summary>

### Base branch breakdown
BASE_PROJECTS_PLACEHOLDER

### PR branch breakdown  
PR_PROJECTS_PLACEHOLDER

</details>

> This information shows the total cost of all infrastructure. The diff above shows only the changes.
EOF

  TOTAL_COMMENT="${TOTAL_COMMENT//BASE_BRANCH_PLACEHOLDER/$BASE_BRANCH}"
  TOTAL_COMMENT="${TOTAL_COMMENT//BASE_TOTAL_PLACEHOLDER/$BASE_TOTAL}"  
  TOTAL_COMMENT="${TOTAL_COMMENT//PR_TOTAL_PLACEHOLDER/$PR_TOTAL}"
  TOTAL_COMMENT="${TOTAL_COMMENT//BASE_PROJECTS_PLACEHOLDER/$BASE_PROJECTS}"
  TOTAL_COMMENT="${TOTAL_COMMENT//PR_PROJECTS_PLACEHOLDER/$PR_PROJECTS}"

  echo "Sending additional comment..."
  
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
       -H "Authorization: token $GITHUB_TOKEN" \
       -H "Accept: application/vnd.github.v3+json" \
       -X POST \
       "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" \
       -d "{\"body\": $(echo "$TOTAL_COMMENT" | jq -Rs .)}")

  if [ "$HTTP_CODE" -eq 201 ]; then
    echo "Additional total cost comment sent (HTTP $HTTP_CODE)"
  else
    echo "Failed to send additional comment (HTTP $HTTP_CODE), but main diff comment was created"
  fi
else
  echo "Cost data files not found, skipping additional comment"
  echo "Checking file presence:"
  ls -la /tmp/infracost-*.json || echo "Files not found"
fi
