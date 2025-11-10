#!/bin/bash
#
# shared helper functions

: "${RUN_AS_DEPLOY_CMD:=sudo -H -u deploy bash -lc}"
: "${RUN_AS_POSTGRES_CMD:=sudo -H -u postgres bash -lc}"

run_as_deploy() {
  local command="$1"
  local node_bin_dir
  node_bin_dir="$(dirname "$(command -v node 2>/dev/null || echo /usr/local/bin/node)")"
  local extra_path="/usr/local/bin:${node_bin_dir}"
  ${RUN_AS_DEPLOY_CMD} "PATH=${extra_path}:\$PATH ${command}"
}

run_as_postgres() {
  local command="$1"
  ${RUN_AS_POSTGRES_CMD} "cd /tmp && ${command}"
}

ensure_directory() {
  local path="$1"
  if [[ -n "${path}" && ! -d "${path}" ]]; then
    mkdir -p "${path}"
  fi
}

