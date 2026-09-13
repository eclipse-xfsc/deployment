IMAGE_REPOSITORY ?= node-654e3bca7fbeeed18f81d7c7.ps-xaas.io/dev-ops/secret-init-container
IMAGE_TAG ?= dev
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER_NAME ?= xfsc-builder

IMAGE := $(IMAGE_REPOSITORY):$(IMAGE_TAG)

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make builder        Create or select the buildx builder"
	@echo "  make build          Build the image for the local platform"
	@echo "  make buildx         Build a multi-platform image without pushing"
	@echo "  make push           Build and push the multi-platform image"
	@echo "  make inspect        Inspect the published image"
	@echo "  make clean-builder  Remove the buildx builder"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_REPOSITORY=$(IMAGE_REPOSITORY)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"
	@echo "  PLATFORMS=$(PLATFORMS)"
	@echo "  BUILDER_NAME=$(BUILDER_NAME)"

.PHONY: builder
builder:
	@if docker buildx inspect "$(BUILDER_NAME)" >/dev/null 2>&1; then \
		echo "Using existing buildx builder $(BUILDER_NAME)"; \
		docker buildx use "$(BUILDER_NAME)"; \
	else \
		echo "Creating buildx builder $(BUILDER_NAME)"; \
		docker buildx create \
			--name "$(BUILDER_NAME)" \
			--driver docker-container \
			--use; \
	fi
	@docker buildx inspect --bootstrap

.PHONY: build
build:
	docker build \
		--tag "$(IMAGE)" \
		.

.PHONY: buildx
buildx: builder
	docker buildx build \
		--platform "$(PLATFORMS)" \
		--tag "$(IMAGE)" \
		--file deployment/docker/Dockerfile \
		--push \
		.

.PHONY: inspect
inspect:
	docker buildx imagetools inspect "$(IMAGE)"

.PHONY: clean-builder
clean-builder:
	@if docker buildx inspect "$(BUILDER_NAME)" >/dev/null 2>&1; then \
		docker buildx rm "$(BUILDER_NAME)"; \
	else \
		echo "Buildx builder $(BUILDER_NAME) does not exist."; \
	fi