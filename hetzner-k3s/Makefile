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
		--from-literal=network="xfsc-network" \
		--dry-run=client -o yaml | kubectl apply -f -; \
	helm repo add hcloud https://charts.hetzner.cloud --force-update; \
	helm repo update; \
	helm upgrade --install hcloud-cloud-controller-manager \
		hcloud/hcloud-cloud-controller-manager \
		--namespace kube-system \
		--set networking.enabled=true \
		--set-string networking.clusterCIDR="10.42.0.0/16" \
		--set env.HCLOUD_TOKEN.valueFrom.secretKeyRef.name=hcloud \
		--set env.HCLOUD_TOKEN.valueFrom.secretKeyRef.key=token \
		--set env.HCLOUD_NETWORK.valueFrom.secretKeyRef.name=hcloud \
		--set env.HCLOUD_NETWORK.valueFrom.secretKeyRef.key=network \
		--set-string env.HCLOUD_NETWORK_ROUTES_ENABLED.value="false"; \
	kubectl rollout status deployment/hcloud-cloud-controller-manager \
		-n kube-system \
		--timeout=180s; \
	kubectl get pods -n kube-system \
		-l app.kubernetes.io/name=hcloud-cloud-controller-manager; \
	kubectl get nodes \
		-o custom-columns=NAME:.metadata.name,PROVIDER_ID:.spec.providerID,INTERNAL_IP:.status.addresses[0].address

ARGOCD_NAMESPACE ?= argocd

terraform-destroy: terraform-install
	@if [ -f kubeconfig.yaml ]; then \
		export KUBECONFIG="$(CURDIR)/kubeconfig.yaml"; \
		\
		echo "Deleting Argo CD ApplicationSets..."; \
		if kubectl get namespace "$(ARGOCD_NAMESPACE)" >/dev/null 2>&1; then \
			kubectl delete applicationsets.argoproj.io \
				--all \
				-n "$(ARGOCD_NAMESPACE)" \
				--wait=true || true; \
		else \
			echo "Argo CD namespace $(ARGOCD_NAMESPACE) does not exist, skipping."; \
		fi; \
		\
		echo "Waiting for Argo CD applications to be removed..."; \
		for i in $$(seq 1 60); do \
			count=$$(kubectl get applications.argoproj.io \
				-n "$(ARGOCD_NAMESPACE)" \
				--no-headers 2>/dev/null | wc -l); \
			if [ "$$count" -eq 0 ]; then \
				echo "All Argo CD applications removed."; \
				break; \
			fi; \
			echo "Still waiting for $$count Argo CD application(s)..."; \
			sleep 5; \
		done; \
		\
		echo "Uninstalling all Helm releases in all namespaces..."; \
		helm list --all-namespaces \
			--output json | \
		jq -r '.[] | [.namespace, .name] | @tsv' | \
		while IFS=$$'\t' read -r ns release; do \
			[ -z "$$ns" ] && continue; \
			[ -z "$$release" ] && continue; \
			echo "Uninstalling Helm release $$ns/$$release"; \
			helm uninstall "$$release" \
				--namespace "$$ns" \
				--wait \
				--timeout 5m || true; \
		done; \
		\
		echo "Deleting remaining Kubernetes LoadBalancer services..."; \
		kubectl get svc -A \
			--field-selector spec.type=LoadBalancer \
			-o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' | \
		while IFS=$$'\t' read -r ns name; do \
			[ -z "$$ns" ] && continue; \
			[ -z "$$name" ] && continue; \
			echo "Deleting LoadBalancer service $$ns/$$name"; \
			kubectl delete svc \
				-n "$$ns" \
				"$$name" \
				--wait=true || true; \
		done; \
		\
		echo "Waiting for HCCM to remove Hetzner Load Balancers..."; \
		sleep 15; \
	fi
	$(TF) destroy

clean:
	rm -rf $(TOOLS_DIR)