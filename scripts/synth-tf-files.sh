#!/bin/bash
set -e

INFRA_PATH=$1
USE_CDKTF=$2

ROOT_DIR=$(pwd)
echo "Root directory: $ROOT_DIR"
echo "Infrastructure path: $INFRA_PATH"
echo "Environment: $ENVIRONMENT"
echo "Use CDKTF: $USE_CDKTF"

# Находим все проекты CDKTF
PROJECTS=$(find "$INFRA_PATH" -name "cdktf.json" -type f | xargs dirname | sort)
echo "Found projects: $PROJECTS"

for project in $PROJECTS; do
  echo "Processing project: $project"
  
  PROJECT_PATH="$ROOT_DIR/$project"

  if [ ! -d "$PROJECT_PATH" ]; then
    echo "Warning: Project directory $PROJECT_PATH does not exist, skipping..."
    continue
  fi
  
  cd "$PROJECT_PATH"
  echo "Changed to: $(pwd)"

  echo "Installing dependencies..."
  pnpm install --frozen-lockfile

  project_name=$(basename "$project")

  if [ "$USE_CDKTF" != "true" ]; then
    echo "Non-CDKTF projects are currently not supported in this simplified script, skipping..."
  else
    echo "Using CDKTF for project: $project_name"

    echo "Running CDKTF synth for $project_name"
    pnpm exec cdktf synth || {
      echo "CDKTF synth failed for $project_name"
      cd "$ROOT_DIR"
      continue
    }

    if [ -d "cdktf.out/stacks" ]; then
      for stack_dir in cdktf.out/stacks/*/; do
        if [ -d "$stack_dir" ]; then
          stack=$(basename "$stack_dir")
          echo "Stack synthesized: $stack in project: $project_name"
        fi
      done
    else
      echo "No stacks directory found in cdktf.out for project: $project_name"
    fi
  fi
  
  cd "$ROOT_DIR"
done

echo "CDKTF synth completed for all projects."
