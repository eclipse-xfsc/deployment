# Hetzner Kubernetes Cluster (Terraform)

This project provisions a production-ready Kubernetes cluster on Hetzner Cloud using Terraform.

The infrastructure is designed to be fully reproducible and disposable. The entire cluster can be created with terraform apply and completely removed using terraform destroy.

Features

* Dedicated control plane and worker node pools
* Highly available K3s cluster with embedded etcd
* Private Hetzner network
* Kubernetes API Load Balancer
* Firewall
* Placement Groups
* Automatic K3s bootstrap
* Terraform-based Infrastructure as Code
* Local Terraform installation via Makefile
* Traefik disabled (Kong Gateway recommended)
* ServiceLB disabled (Hetzner Cloud Controller Manager recommended)


# Prerequisites

Before you begin, ensure you have:

* A Hetzner Cloud account
* A Hetzner Cloud API token
* An SSH public key
* Linux or macOS

Required tools:

* make
* curl
* unzip
* ssh
* scp

Terraform is downloaded automatically by the provided Makefile.


# Project Structure

.
├── Makefile
├── README.md
├── versions.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── main.tf
├── terraform.tfvars.example
├── cloud-init/
│   ├── control-plane.yaml
│   └── worker.yaml
└── scripts/
    └── get-kubeconfig.sh

# Configuration

Copy the example configuration:

cp terraform.tfvars.example terraform.tfvars

Configure your cluster:

cluster_name = "xsfc"
location = "nbg1"
network_cidr = "10.10.0.0/16"
ssh_public_key = "ssh-ed25519 AAAA..."
control_plane_count = 3
control_plane_server_type = "cx22"
worker_count = 3
worker_server_type = "cx32"
disable_traefik = true
disable_servicelb = true

Supported Hetzner Locations

Location	Region
fsn1	Falkenstein
nbg1	Nuremberg
hel1	Helsinki


# Authentication

Create an API token in the Hetzner Cloud Console:

Security
└── API Tokens

Export the token before running Terraform:

export HCLOUD_TOKEN=<your-token>

Alternatively:

export TF_VAR_hcloud_token=<your-token>


# Deploy the Cluster

Initialize Terraform:

make terraform-init

Validate the configuration:

make terraform-validate

Review the execution plan:

make terraform-plan

Create the infrastructure:

make terraform-apply

Provisioning typically takes between 3 and 8 minutes, depending on the number of nodes.


# Retrieve the Kubeconfig

After the cluster has been created:

./scripts/get-kubeconfig.sh

Export it:

export KUBECONFIG=$(pwd)/kubeconfig.yaml

Verify the cluster:

kubectl get nodes -o wide

# Destroy the Cluster

To completely remove all resources:

make terraform-destroy

Terraform removes:

* Control plane nodes
* Worker nodes
* Load Balancer
* Private network
* Firewall
* Placement Groups
* Volumes
* Remaining Terraform-managed infrastructure

# Available Make Targets

Target	Description
terraform-install	Download Terraform locally
terraform-version	Show Terraform version
terraform-init	Initialize Terraform
terraform-fmt	Format Terraform files
terraform-validate	Validate the configuration
terraform-plan	Generate an execution plan
terraform-apply	Create or update infrastructure
terraform-destroy	Destroy the infrastructure
clean	Remove locally installed tools

# Cluster Architecture

                        Internet
                            │
                 Hetzner Load Balancer
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
   Control Plane 1   Control Plane 2   Control Plane 3
      (embedded etcd)   (embedded etcd)   (embedded etcd)
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
               Private Hetzner Network
                            │
        ┌────────────┬────────────┬────────────┐
        │            │            │
     Worker 1     Worker 2     Worker 3


# Scaling

Increase the number of worker nodes:

worker_count = 6

Apply the changes:

make terraform-apply

Increase the control plane:

control_plane_count = 5

Recommendation: Always use an odd number of control plane nodes (1, 3, 5, …) to maintain etcd quorum.


# Node Configuration

Control plane and worker nodes can be configured independently.

Example:

control_plane_server_type = "cx22"
worker_server_type        = "cx42"

This allows you to optimize the cluster for both cost and workload requirements.

# High Availability

The cluster is designed for high availability and production workloads.

Features include:

* Multiple control plane nodes
* Embedded etcd cluster
* Kubernetes API behind a Load Balancer
* Private networking between all nodes
* Placement Groups to distribute nodes across different physical hosts


# Networking

The cluster uses:

* Private Hetzner Network
* Internal node-to-node communication
* Public access only through the Kubernetes API Load Balancer
* Firewall rules restricting unnecessary inbound traffic


# Default K3s Configuration

The cluster intentionally disables K3s’ built-in networking components:

Component	Status	Replacement
Traefik	Disabled	Kong Gateway
ServiceLB	Disabled	Hetzner Cloud Controller Manager

This provides a clean Kubernetes installation without unnecessary components.