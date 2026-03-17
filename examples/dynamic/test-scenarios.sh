#!/usr/bin/env bash

set -eo pipefail

max_iterations=10
this_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$this_dir"
total_runs=0

terraform init -reconfigure

while true; do
  terraform apply -auto-approve && \
    terraform apply && \
    terraform apply -var delete_manifest=true -auto-approve &&
    terraform apply -var delete_manifest=true && \
    terraform destroy -auto-approve && \
  terraform apply -var delete_manifest=true -auto-approve && \
    terraform apply -var delete_manifest=true && \
    terraform apply -auto-approve && \
    terraform apply &&
    terraform destroy -auto-approve
  (( total_runs ++ ))
  if [ $total_runs -ge $max_iterations ]; then
    echo "SUCCESS: went through $max_iterations iterations of applies destroys and they all worked"
    exit 0
  fi
done
