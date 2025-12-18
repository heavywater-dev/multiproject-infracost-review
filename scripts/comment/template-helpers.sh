#!/bin/bash

replace_template_vars() {
  local template="$1"
  local summary="$2"
  local diff="$3"

  template="${template//\{\{SUMMARY\}\}/$summary}"
  template="${template//\{\{DIFF_CONTENT\}\}/$diff}"

  echo "$template"
}
