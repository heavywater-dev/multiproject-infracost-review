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