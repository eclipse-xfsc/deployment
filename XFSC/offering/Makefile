IMAGE_REPOSITORY ?= node-654e3bca7fbeeed18f81d7c7.ps-xaas.io/ocm-wstack/credential-offering-bootstrap
IMAGE_TAG ?= dev
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER_NAME ?= xfsc-builder

IMAGE := $(IMAGE_REPOSITORY):$(IMAGE_TAG)
DOCKERFILE ?= Dockerfile

HELM_REPOSITORY ?= oci://node-654e3bca7fbeeed18f81d7c7.ps-xaas.io/ocm-wstack
HELM_CHART_DIR ?= deployment/helm
HELM_DIST_DIR ?= dist/helm
HELM_CHART_VERSION ?= 0.1.0
HELM_APP_VERSION ?= $(IMAGE_TAG)

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make builder        Create or select the buildx builder"
	@echo "  make build          Build the image for the local platform"
	@echo "  make buildx         Build and push the multi-platform image"
	@echo "  make push           Alias for buildx"
	@echo "  make inspect        Inspect the published image"
	@echo "  make clean-builder  Remove the buildx builder"
	@echo "  make helm-lint      Lint the Helm chart"
	@echo "  make helm-template  Render the Helm chart"
	@echo "  make helm-package   Package the Helm chart"
	@echo "  make helm-build     Lint, render and package the Helm chart"
	@echo "  make helm-push      Package and push the Helm chart to OCI"
	@echo "  make release        Push image and Helm chart"
	@echo "  make clean          Remove generated Helm artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_REPOSITORY=$(IMAGE_REPOSITORY)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"
	@echo "  PLATFORMS=$(PLATFORMS)"
	@echo "  BUILDER_NAME=$(BUILDER_NAME)"
	@echo "  HELM_REPOSITORY=$(HELM_REPOSITORY)"
	@echo "  HELM_CHART_VERSION=$(HELM_CHART_VERSION)"
	@echo "  HELM_APP_VERSION=$(HELM_APP_VERSION)"

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
		--file "$(DOCKERFILE)" \
		.

.PHONY: buildx
buildx: builder
	docker buildx build \
		--platform "$(PLATFORMS)" \
		--tag "$(IMAGE)" \
		--file "$(DOCKERFILE)" \
		--push \
		.

.PHONY: push
push: buildx

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

.PHONY: helm-lint
helm-lint:
	helm lint "$(HELM_CHART_DIR)"

.PHONY: helm-template
helm-template:
	helm template credential-offering-bootstrap "$(HELM_CHART_DIR)" \
		--set-string image.repository="$(IMAGE_REPOSITORY)" \
		--set-string image.tag="$(IMAGE_TAG)" >/dev/null

$(HELM_DIST_DIR):
	mkdir -p "$(HELM_DIST_DIR)"

.PHONY: helm-package
helm-package: $(HELM_DIST_DIR)
	helm package "$(HELM_CHART_DIR)" \
		--destination "$(HELM_DIST_DIR)" \
		--version "$(HELM_CHART_VERSION)" \
		--app-version "$(HELM_APP_VERSION)"

.PHONY: helm-build
helm-build: helm-lint helm-template helm-package

.PHONY: helm-push
helm-push: helm-lint helm-template helm-package
	helm push "$(HELM_DIST_DIR)/credential-offering-bootstrap-$(HELM_CHART_VERSION).tgz" "$(HELM_REPOSITORY)"

.PHONY: release
release: push helm-push

.PHONY: clean
clean:
	rm -rf "$(HELM_DIST_DIR)"
