OPS_IMAGE_NAME := terraform-aws-lambda-eks-apply-ops
OPS_CONTAINER_NAME := terraform-aws-lambda-eks-apply-ops-container
OPS_CONTAINER_RESET ?= false
export

.PHONY: test
test: lambda-test module-test

.PHONY: lambda-test
lambda-test:
	cd lambda && $(MAKE) test

.PHONY: module-test
module-test: ops-container
	docker exec -i $(OPS_CONTAINER_NAME) /bin/bash -c "tfswitch && terraform init -reconfigure && terraform validate"

.PHONY: docs
docs: ops-container
	docker exec -i $(OPS_CONTAINER_NAME) terraform-docs . --config=.terraform-docs.yml --output-mode replace --output-file README.md

.PHONY: fmt
fmt: ops-container
	docker exec -i $(OPS_CONTAINER_NAME) /bin/bash -c "tfswitch && terraform fmt -recursive"

.PHONY: ops-container
ops-container:
	@reset_container=$(OPS_CONTAINER_RESET); \
	if ! docker inspect $(OPS_CONTAINER_NAME) > /dev/null 2>&1; then \
		reset_container=true; \
	fi; \
	if [[ "$${reset_container}" == true ]]; then \
		docker rm -f $(OPS_CONTAINER_NAME) &>/dev/null; \
		docker build -t $(OPS_IMAGE_NAME) -f ops.dockerfile .; \
		docker run -i -d -v "$$(pwd):/workdir" -w /workdir --name $(OPS_CONTAINER_NAME) $(OPS_IMAGE_NAME) -c "tail -f /dev/null"; \
	fi;



