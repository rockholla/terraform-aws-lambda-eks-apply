#!/usr/bin/env bash

set -eo pipefail

export TEST_FUNCTION_CONTAINER_PORT=9000
export TEST_EXPECT_FAILURE=true
export TEST_FAILED_MSG_PREFIX="==> TEST FAILED: "
export YQ_VERSION="4.52.2"
export KIND_VERSION="v0.31.0"
export IN_TESTS_CONTAINER_KUBECONFIG_PATH=".tmp/kubeconfig-internal.yml"

. "$(git rev-parse --show-toplevel)/scripts/.lib.sh"
_this_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

require_variable_value "LOCAL_IMAGE_NAME"
require_binary "docker"
require_binary "curl"
handle_errors "exit 1"

TESTS_NAME="$(get_repo_name)"
export TESTS_NAME

function yq_local() {
  docker run --rm -i -v "$(pwd):/workdir" -w /workdir "mikefarah/yq:${YQ_VERSION}" "$@"
}

function ensure_kind_local() {
  mkdir -p "${_this_dir}/.bin"
  info "Ensuring on-demand versions of dependencies are available for tests..."
  if [[ ! -f "${_this_dir}/.bin/kind" ]] || [[ "v$("${_this_dir}"/.bin/kind --version | awk '{print $NF}')" != "${KIND_VERSION}" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      [ "$(uname -m)" = "x86_64" ] && curl -Lo "${_this_dir}/.bin/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-darwin-amd64"
      [ "$(uname -m)" = "arm64" ] && curl -Lo "${_this_dir}/.bin/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-darwin-arm64"
      chmod +x ./.bin/kind
    elif [[ "$(uname -s)" == "Linux" ]]; then
      [ "$(uname -m)" = "x86_64" ] && curl -Lo "${_this_dir}/.bin/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
      [ "$(uname -m)" = "aarch64" ] && curl -Lo "${_this_dir}/.bin/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-arm64"
      chmod +x ./.bin/kind
    else
      err "Unsupported system type $(uname -s) for running kind for these tests"
    fi
  fi
  handle_errors "exit 1"
}

function kind_local() {
  "${_this_dir}"/.bin/kind "$@"
}

function run_tests_container() {
  info "Starting Lambda tests container w/ image ${LOCAL_IMAGE_NAME}"
  docker run --name "${TESTS_NAME}" -v "${_this_dir}:/tests" --network kind -d -p "${TEST_FUNCTION_CONTAINER_PORT}:8080" "$LOCAL_IMAGE_NAME"
  info "Copying secrets mock into test container"
  docker cp "${_this_dir}/secrets-mock.py" "${TESTS_NAME}:/var/task/secrets.py"
}

function test_container_kubectl() {
  docker exec -i -w /tests "${TESTS_NAME}" kubectl --kubeconfig "${IN_TESTS_CONTAINER_KUBECONFIG_PATH}" "$@"
}

function start_test_section() {
  local test_name="$1"
  echo ""
  echo "=============================================================================================================================================="
  info "${BOLD}Running test: ${test_name}${NO_COLOR}"
}

function wait_for_k8s_resource() {
  local resource_type_and_name="$1"
  local resource_namespace="$2"

  local timeout=10
  end_time=$((SECONDS + timeout))
  resource_name_log="${resource_type_and_name}"
  if [ -n "$resource_namespace" ]; then
    resource_name_log="${resource_name_log} in namespace ${resource_namespace}"
  fi
  printf "${WARN_COLOR}Waiting${NO_COLOR} for %s to be present..." "${resource_name_log}"
  found=false
  while [ $SECONDS -lt $end_time ]; do
    if test_container_kubectl get "${resource_type_and_name}" &>/dev/null; then
      found=true
      break
    fi
    sleep 2
  done
  if [[ "$found" != true ]]; then
    err "Error: did not find ${resource_name_log} w/in the timeout period"
  else
    printf "${BOLD}%s${NO_COLOR}\n" "FOUND"
  fi
}

function test_invoke_lambda_function() {
  local inputs="$1"
  local expect_failure="${2:-false}"
  local failed_invoke=false
  invoke_result="$(curl -s -XPOST "http://localhost:${TEST_FUNCTION_CONTAINER_PORT}/2015-03-31/functions/function/invocations" -d "${inputs}")"
  status_code="$(echo "$invoke_result" | yq -r '.statusCode // ""')"
  if [[ "$status_code" != 200 ]] ; then
    failed_invoke=true
  fi
  if [[ "$expect_failure" != "$failed_invoke" ]]; then
    err "${TEST_FAILED_MSG_PREFIX}${invoke_result}"
  else
    echo "$invoke_result"
  fi
}

function assert_contains() {
  local result="$1"
  local should_contain="$2"

  if [[ "$result" != *"$should_contain"* ]]; then
    err "Expected '${result}' to contain '${should_contain}'"
  else
    info "Found expected content in: ${result}"
  fi
}

function cleanup() {
  kind_local delete cluster --name "$TESTS_NAME" &>/dev/null || true
  docker rm -f "${TESTS_NAME}" &>/dev/null || true
}
cleanup
trap 'cleanup' EXIT
ensure_kind_local
kind_local create cluster --name "$TESTS_NAME" --kubeconfig "${_this_dir}/.tmp/kubeconfig.yml"
kind_local get kubeconfig --name "$TESTS_NAME" --internal > "${_this_dir}/${IN_TESTS_CONTAINER_KUBECONFIG_PATH}"
