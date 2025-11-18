#!/bin/bash
set -e

INFRA_PATH=$1
ENVIRONMENT=$2

ROOT_DIR=$(pwd)
echo "Root directory: $ROOT_DIR"
echo "Infrastructure path: $INFRA_PATH"
echo "Environment: $ENVIRONMENT"

PROJECTS=$(find "$INFRA_PATH" -name "cdktf.json" -type f | xargs dirname | sort)
echo "Found CDKTF projects: $PROJECTS"

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
  echo "Running synthesis for project: $project_name"

  if [ ! -d "cdktf.out" ]; then
    echo "Fallback: using direct cdktf synth for $project_name"
    pnpm exec cdktf synth || {
      echo "Direct cdktf synth also failed for $project_name"
      cd "$ROOT_DIR"
      continue
    }
  fi

  if [ -d "cdktf.out/stacks" ]; then
    for stack_dir in cdktf.out/stacks/*/; do
      if [ -d "$stack_dir" ]; then
        stack=$(basename "$stack_dir")
        echo "Processing stack: $stack in project: $project_name"
        
        STACK_PATH="$PROJECT_PATH/$stack_dir"
        cd "$STACK_PATH"

        if [ -f "cdk.tf.json" ]; then
          echo "Removing remote backend configuration for local planning..."
          jq 'del(.terraform.backend)' cdk.tf.json > cdk.tf.json.tmp && mv cdk.tf.json.tmp cdk.tf.json
        fi

        echo "Initializing Terraform for stack: $stack"
        terraform init

        echo "Generating Terraform plan for stack: $stack"
        terraform plan -out=plan.tfplan || {
          echo "Plan failed for $stack in $project_name, continuing..."
        }

        cd "$PROJECT_PATH"
      fi
    done
  else
    echo "No stacks directory found in cdktf.out for project: $project_name"
  fi
  
  cd "$ROOT_DIR"
done

echo "Baseline plan generation completed."
