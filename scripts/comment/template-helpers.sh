#!/bin/bash

replace_template_vars() {
  local template="$1"
  local total_cost="$2" 
  local diff_content="$3"
  
  echo "$template" | sed \
    -e "s|{{TOTAL_COST_TABLE}}|$total_cost|g" \
    -e "s|{{DIFF_CONTENT}}|$diff_content|g"
}

format_resource_row() {
  local name="$1"
  local type="$2"
  local cost_change="$3"
  
  echo "| $name | $type | $cost_change |"
}

format_project_section() {
  local project_name="$1"
  local has_resources="$2"
  local resources_table="$3"
  local project_total="$4"
  
  if [[ "$has_resources" == "true" ]]; then
    cat << EOF
## $project_name

| Resource | Type | Monthly Cost Change |
|----------|------|---------------------|
$resources_table

**Total change for this project:** $project_total

---
EOF
  else
    cat << EOF
## $project_name

No resource changes in this project.

---
EOF
  fi
}
