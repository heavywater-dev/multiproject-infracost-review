#!/bin/bash
set -e

while [[ $# -gt 0 ]]; do
  case $1 in
    --base-file) BASE="$2"; shift 2 ;;
    --head-file) HEAD="$2"; shift 2 ;;
    --out-file) OUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "Generating Infracost diff: $BASE vs $HEAD -> $OUT"

infracost diff \
  --path="$BASE" \
  --compare-to="$HEAD" \
  --format=json \
  --out-file="$OUT"

echo "Diff completed: $OUT"

if [ -f "$BASE" ] && [ -f "$HEAD" ]; then
  BASE_TOTAL=$(jq -r '.totalMonthlyCost // "0"' "$BASE")
  HEAD_TOTAL=$(jq -r '.totalMonthlyCost // "0"' "$HEAD")
  BASE_BRANCH="${GITHUB_BASE_REF:-main}"

  read -r -d '' TOTAL_COST_MARKDOWN <<EOF || true
---
## Total Infrastructure Cost

| | Cost |
|---|---|
| **Base branch ($BASE_BRANCH)** | \$${BASE_TOTAL}/month |
| **PR branch** | \$${HEAD_TOTAL}/month |
EOF

  jq --arg tc "$TOTAL_COST_MARKDOWN" '. + {metadata: {totalCostComment: $tc}}' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"

  echo "Added total cost info to diff JSON"
fi
