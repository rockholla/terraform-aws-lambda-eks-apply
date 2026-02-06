LOCAL_IMAGE_NAME := rockholla/lambda-eks-apply
export

.PHONY: test
test:
	@docker build -t $(LOCAL_IMAGE_NAME) .
	@./tests/test.sh

version ?=
description ?=
latest ?= false
prerelease_arg := -p
ifeq (latest, true)
prerelease_arg :=
endif
.PHONY: release
release:
	@if [ -n "$$(git status -s)" ]; then echo "error: releasing only allowed on a clean working tree"; exit 1; fi; \
	if [ -z "$(version)" ]; then echo "error: please provide the 'version' for the release"; exit 1; fi; \
	if [ -z "$(description)" ]; then echo "error: please provide the 'description' for the release"; exit 1; fi; \
	if gh release view lambda/$(version) --repo rockholla/terraform-aws-lambda-eks-apply; then echo "error: release/tag $(version) already exists"; exit 1; fi;
	echo gh release create lambda/$(version) --notes "$(description)" --latest=$(latest) $(prerelease_arg)



