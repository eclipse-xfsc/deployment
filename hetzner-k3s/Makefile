SHELL := /bin/bash

TERRAFORM_VERSION ?= 1.13.1

TOOLS_DIR := .tools
TF := $(TOOLS_DIR)/terraform


KEY_DIR := keys
SSH_KEY := $(KEY_DIR)/id_xfsc

.PHONY: 

.PHONY: all \
	terraform-install \
	terraform-version \
	terraform-init \
	terraform-validate \
	terraform-fmt \
	terraform-plan \
	terraform-apply \
	terraform-destroy \
	ssh-key \
	clean

all: terraform-version

ssh-key:
	@mkdir -p $(KEY_DIR)
	@if [ -f "$(SSH_KEY)" ]; then \
		echo "SSH key already exists: $(SSH_KEY)"; \
	else \
		echo "Generating ED25519 SSH key..."; \
		ssh-keygen -t ed25519 \
			-a 100 \
			-f $(SSH_KEY) \
			-C "xfsc-kubernetes" \
			-N ""; \
		echo ""; \
		echo "Public key:"; \
		cat $(SSH_KEY).pub; \
	fi

terraform-install:
	@mkdir -p $(TOOLS_DIR)
	@if [ -f "$(TF)" ]; then \
		echo "Terraform already installed."; \
		exit 0; \
	fi; \
	OS=$$(uname | tr '[:upper:]' '[:lower:]'); \
	ARCH=$$(uname -m); \
	case $$ARCH in \
		x86_64|amd64) ARCH=amd64 ;; \
		arm64|aarch64) ARCH=arm64 ;; \
		*) echo "Unsupported architecture: $$ARCH"; exit 1 ;; \
	esac; \
	URL="https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$${OS}_$${ARCH}.zip"; \
	echo "Downloading Terraform $(TERRAFORM_VERSION)..."; \
	curl -fsSL "$$URL" -o terraform.zip; \
	unzip -oq terraform.zip -d $(TOOLS_DIR); \
	rm terraform.zip; \
	chmod +x $(TF); \
	echo "Terraform installed successfully."

terraform-version: terraform-install
	$(TF) version

terraform-init: terraform-install
	$(TF) init

terraform-validate: terraform-install
	$(TF) validate

terraform-fmt: terraform-install
	$(TF) fmt -recursive

terraform-plan: terraform-install
	$(TF) plan

terraform-apply: terraform-install
	$(TF) apply
	./scripts/get-kubeconfig.sh
	export KUBECONFIG="$(CURDIR)/kubeconfig.yaml"; \
	kubectl -n kube-system create secret generic hcloud \
		--from-literal=token="$${HCLOUD_TOKEN}" \
		--dry-run=client -o yaml | kubectl apply -f -; \
	helm repo add hcloud https://charts.hetzner.cloud --force-update; \
	helm repo update; \
	helm upgrade --install hcloud-cloud-controller-manager \
		hcloud/hcloud-cloud-controller-manager \
		--namespace kube-system \
		--set env.HCLOUD_TOKEN.valueFrom.secretKeyRef.name=hcloud \
		--set env.HCLOUD_TOKEN.valueFrom.secretKeyRef.key=token; \
	kubectl rollout status deployment/hcloud-cloud-controller-manager \
		-n kube-system \
		--timeout=180s; \
	kubectl get pods -n kube-system -l app.kubernetes.io/name=hcloud-cloud-controller-manager

terraform-destroy: terraform-install
	$(TF) destroy

clean:
	rm -rf $(TOOLS_DIR)