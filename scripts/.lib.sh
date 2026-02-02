#!/usr/bin/env bash

set -eo pipefail

export NO_COLOR="\e[0m"
export ERROR_COLOR="\e[31m"
export WARN_COLOR="\e[33m"
export OK_COLOR="\e[32m"
export BOLD="\e[1m"

function require_variable_value() {
  local variable_name="$1"
  local variable_value="${!variable_name}"
  if [ -z "$variable_value" ]; then
    err "$variable_name is required"
  fi
}

function require_binary() {
  local name="$1"
  if ! command -v "$name" &>/dev/null; then
    err "$name is required"
  fi
}

function warn() {
  local msg="$1"
  local warning="${WARN_COLOR}WARNING:${NO_COLOR} $msg"
  # shellcheck disable=SC2059
  >&2 printf "$warning\n"
}

_errors=false
function err() {
  local msg="$1"
  local err="${ERROR_COLOR}ERROR:${NO_COLOR} $msg"
  # shellcheck disable=SC2059
  >&2 printf "$err\n"
  _errors=true
}

function info() {
  local msg="$1"
  local info="${OK_COLOR}INFO:${NO_COLOR} $msg"
  # shellcheck disable=SC2059
  printf "$info\n"
}

function handle_errors() {
  local handler="$1"
  if [[ $_errors == true ]]; then
    eval "$handler"
  fi
}

function usage() {
  local msg="$1"
  local msg_type="$2" # either 'error'/exit 1 or warn/exit 0 if anything else
  local msg_color="${WARN_COLOR}"
  local exit_code=0
  if [[ "$msg_type" == "error" ]]; then
    msg_color="${ERROR_COLOR}"
    exit_code=1
  fi
  local usage="${msg_color}Usage:${NO_COLOR} $msg"
  # shellcheck disable=SC2059
  printf "$usage\n"
  exit $exit_code
}

function get_repo_root() {
  git rev-parse --show-toplevel
}

function get_repo_name() {
  basename "$(git remote get-url origin)" .git
}

function get_branch_name() {
  if [[ -n "${BUILDKITE_BRANCH:-}" ]]; then
    echo "$BUILDKITE_BRANCH"
  else
    git rev-parse --abbrev-ref HEAD
  fi
}

# these hashes don't need to be absolutely unique, just some approximation
# of uniqueness for generic strings provided, so the cutting to 8 chars
# represents this approximation
function get_string_short_hash() {
  local str
  str="$1"
  hasher="md5sum"
  if command -v md5sum &>/dev/null; then
    hasher="md5sum"
  elif command -v md5 &>/dev/null; then
    hasher="md5"
  elif command -v sha1sum &>/dev/null; then
    hasher="sha1sum"
  elif command -v shasum &>/dev/null; then
    hasher="shasum"
  fi
  echo "$str" | $hasher | cut -c1-8
}

function get_file_short_hash() {
  local file_path="$1"
  get_string_short_hash "$(cat "$file_path")"
}

# Initialize and return a dedicated temporary directory
function get_tmpdir() {
  local tmpdir
  tmpdir="${TMPDIR:-/tmp/}cn"
  mkdir -p "$tmpdir"
  realpath "$tmpdir"
}

# gets the remote/origin default branch name
function get_origin_default_branch() {
  git remote show origin | grep 'HEAD branch' | cut -d: -f2 | sed -e 's/^[ \t]*//'
}
