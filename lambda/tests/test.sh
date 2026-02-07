#!/usr/bin/env bash

set -eo pipefail

this_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${this_dir}/.lib.sh"

cd "${this_dir}"

run_tests_container
mkdir -p ./.tmp

cluster_ca_certificate_data="$(yq_local -r '.clusters[0].cluster.certificate-authority-data' "${IN_TESTS_CONTAINER_KUBECONFIG_PATH}")"
cluster_endpoint="$(yq_local -r '.clusters[0].cluster.server' "${IN_TESTS_CONTAINER_KUBECONFIG_PATH}")"

info "Setting up tests admin user for applies"
test_container_kubectl create serviceaccount admin-user -n default
test_container_kubectl create clusterrolebinding admin-user-binding --clusterrole=cluster-admin --serviceaccount=default:admin-user
info "Generating auth token for tests admin user"
auth_token="$(test_container_kubectl create token admin-user -n default)"
info "Generated temporary auth token for tests admin user: **********${auth_token: -5}"

sleep 2

###################### static-namespaces ######################
start_test_section "static-namespaces apply"
inputs=$(cat <<EOT
{
  "cluster_ca_certificate_data":"${cluster_ca_certificate_data}",
  "cluster_endpoint":"${cluster_endpoint}",
  "cluster_token_secret_name":"${auth_token}",
  "manifest_template_base64":"$(cat ./.fixtures/static-namespaces.yml | base64)"
}
EOT
)
result="$(test_invoke_lambda_function "$inputs")"
wait_for_k8s_resource "ns/test-namespace-01"
wait_for_k8s_resource "ns/test-namespace-02"

###################### missing manifest template input ######################
start_test_section "missing manifest template input"
inputs=$(cat <<EOT
{
  "cluster_ca_certificate_data":"${cluster_ca_certificate_data}",
  "cluster_endpoint":"${cluster_endpoint}",
  "cluster_token_secret_name":"${auth_token}"
}
EOT
)
result="$(test_invoke_lambda_function "$inputs" "${TEST_EXPECT_FAILURE}")"
assert_contains "$result" "KeyError"

###################### invalid-k8s-resource ######################
start_test_section "invalid-k8s-resource apply"
inputs=$(cat <<EOT
{
  "cluster_ca_certificate_data":"${cluster_ca_certificate_data}",
  "cluster_endpoint":"${cluster_endpoint}",
  "cluster_token_secret_name":"${auth_token}",
  "manifest_template_base64":"$(cat ./.fixtures/invalid-k8s-resource.yml | base64)"
}
EOT
)
result="$(test_invoke_lambda_function "$inputs" "${TEST_EXPECT_FAILURE}")"
assert_contains "$result" 'no matches for kind'

###################### basic-templated ######################
start_test_section "basic-templated apply"
inputs=$(cat <<EOT
{
  "cluster_ca_certificate_data":"${cluster_ca_certificate_data}",
  "cluster_endpoint":"${cluster_endpoint}",
  "cluster_token_secret_name":"${auth_token}",
  "manifest_template_base64":"$(cat ./.fixtures/basic-templated.yml | base64)",
  "namespace":"test-namespace-03"
}
EOT
)
result="$(test_invoke_lambda_function "$inputs")"
wait_for_k8s_resource "ns/test-namespace-03"

###################### kubectl delete ######################
start_test_section "basic-templated delete"
inputs=$(cat <<EOT
{
  "cluster_ca_certificate_data":"${cluster_ca_certificate_data}",
  "cluster_endpoint":"${cluster_endpoint}",
  "cluster_token_secret_name":"${auth_token}",
  "manifest_template_base64":"$(cat ./.fixtures/basic-templated.yml | base64)",
  "namespace":"test-namespace-03",
  "kubectl_operation":"delete"
}
EOT
)
result="$(test_invoke_lambda_function "$inputs")"
assert_contains "$result" 'deleted'

echo ""
handle_errors "exit 1"
info "All tests passed!"
