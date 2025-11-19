#!/bin/bash
set -e

INFRA_PATH=$1
export ENVIRONMENT=$2
OUT_FILE=$3

ROOT_DIR=$(pwd)
echo "Root directory: $ROOT_DIR"
echo "Infrastructure path: $INFRA_PATH"
echo "Environment: $ENVIRONMENT"
echo "Output file: $OUT_FILE"

PROJECTS=$(find "$INFRA_PATH" -name "cdktf.json" -type f | xargs dirname | sort || true)
if [ -z "$PROJECTS" ]; then
  echo "No CDKTF projects found under $INFRA_PATH"
  echo '{"projects":[]}' > "$OUT_FILE"
  exit 0
fi

INFRACOST_CONFIG="/tmp/infracost-config.yml"
echo "version: 0.1" > "$INFRACOST_CONFIG"
echo "projects:" >> "$INFRACOST_CONFIG"

echo "Building Infracost config (HCL mode)..."
for project in $PROJECTS; do
  project_name=$(basename "$project")

  if [ -d "$project/cdktf.out/stacks" ]; then
    for stack_dir in "$project"/cdktf.out/stacks/*/; do
      [ -d "$stack_dir" ] || continue
      stack_name=$(basename "$stack_dir")

      rel_path=${stack_dir#$ROOT_DIR/}
      rel_path=${rel_path%/}

      echo "  - path: $rel_path" >> "$INFRACOST_CONFIG"
      echo "    name: ${project_name}-${stack_name}" >> "$INFRACOST_CONFIG"
    done
  else
    echo "No stacks directory for project $project_name" >&2
  fi
done

echo "Generated Infracost config YAML:"
cat "$INFRACOST_CONFIG"

echo "Running infracost breakdown..."
infracost breakdown --config-file="$INFRACOST_CONFIG" \
  --format=json \
  --out-file="$OUT_FILE"

echo "Infracost breakdown JSON written to $OUT_FILE"
