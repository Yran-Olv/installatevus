#!/bin/bash
#
# shared helper functions

: "${RUN_AS_DEPLOY_CMD:=sudo -H -u deploy bash -lc}"

run_as_deploy() {
  local command="$1"
  ${RUN_AS_DEPLOY_CMD} "${command}"
}

ensure_directory() {
  local path="$1"
  if [[ -n "${path}" && ! -d "${path}" ]]; then
    mkdir -p "${path}"
  fi
}

