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

echo "Building Infracost config from Terraform plan files..."
for project in $PROJECTS; do
  project_name=$(basename "$project")

  if [ -d "$project/cdktf.out/stacks" ]; then
    for stack_dir in "$project"/cdktf.out/stacks/*/; do
      [ -d "$stack_dir" ] || continue
      stack=$(basename "$stack_dir")
      plan_file="$stack_dir/plan.tfplan"
      if [ -f "$plan_file" ]; then
        rel_plan=${plan_file#$ROOT_DIR/}
        echo "  - name: ${project_name}-${stack}" >> "$INFRACOST_CONFIG"
        echo "    terraform_plan_file: $rel_plan" >> "$INFRACOST_CONFIG"
      else
        echo "Plan file missing for $project_name/$stack (expected $plan_file), skipping entry." >&2
      fi
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