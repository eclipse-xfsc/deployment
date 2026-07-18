variable "hcloud_token" {
  description = "Hetzner Cloud API token. Prefer the HCLOUD_TOKEN environment variable or a local tfvars file."
  type        = string
  sensitive   = true
  default     = null
}

variable "enable_node_public_ipv6" {
  description = "Assign public IPv6 addresses to nodes."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Prefix used for all cluster resources."
  type        = string
  default     = "xsfc"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must contain lowercase letters, digits or hyphens and be 3-32 characters long."
  }
}

variable "location" {
  description = "Hetzner location for servers and load balancer, e.g. fsn1, nbg1 or hel1."
  type        = string
  default     = "nbg1"
}

variable "image" {
  description = "Operating system image."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key_file" {
  description = "Path to the SSH public key."
  type        = string
  default     = "keys/id_xfsc.pub"
}

variable "ssh_allowed_cidrs" {
  description = "Public IPv4/IPv6 CIDRs allowed to SSH to nodes. Restrict this in production."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "kubernetes_api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "control_plane_count" {
  description = "Number of K3s server/control-plane nodes. Use 1 or an odd number >= 3."
  type        = number
  default     = 3

  validation {
    condition = floor(var.control_plane_count) == var.control_plane_count && (
      var.control_plane_count == 1 ||
      (var.control_plane_count >= 3 && var.control_plane_count % 2 == 1)
    )
    error_message = "control_plane_count must be 1 or an odd number greater than or equal to 3."
  }
}

variable "control_plane_server_type" {
  description = "Hetzner server type for control-plane nodes."
  type        = string
  default     = "cx23"
}

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = floor(var.worker_count) == var.worker_count && var.worker_count >= 0
    error_message = "worker_count must be a non-negative integer."
  }
}

variable "worker_server_type" {
  description = "Hetzner server type for worker nodes."
  type        = string
  default     = "cx33"
}

variable "control_plane_start_ip" {
  description = "Last octet offset inside the private subnet for control-plane nodes."
  type        = number
  default     = 10
}

variable "worker_start_ip" {
  description = "Last octet offset inside the private subnet for worker nodes."
  type        = number
  default     = 100
}

variable "network_cidr" {
  description = "Private Hetzner network CIDR. Must not overlap with the K3s pod or service CIDRs."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrhost(var.network_cidr, 0))
    error_message = "network_cidr must be a valid CIDR."
  }
}

variable "subnet_cidr" {
  description = "Private subnet CIDR."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR."
  }
}

variable "network_zone" {
  description = "Hetzner network zone. European locations use eu-central."
  type        = string
  default     = "eu-central"
}

variable "k3s_version" {
  description = "K3s version to install."
  type        = string
  default     = "v1.34.1+k3s1"
}

variable "cluster_token" {
  description = "Optional pre-defined K3s cluster token. When null, Terraform creates one and stores it in state."
  type        = string
  sensitive   = true
  default     = null
}

variable "disable_traefik" {
  description = "Disable the bundled Traefik ingress controller. Set to true when using Kong as the ingress controller/API gateway."
  type        = bool
  default     = true
}

variable "disable_servicelb" {
  description = "Disable the bundled K3s ServiceLB controller. Set to true when using the Hetzner Cloud Controller Manager for LoadBalancer services."
  type        = bool
  default     = true
}

variable "enable_node_public_ipv4" {
  description = "Assign public IPv4 addresses to nodes. Disable only when private access and outbound internet connectivity are provided separately."
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable Hetzner server backups."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Additional labels applied to all resources that support labels."
  type        = map(string)
  default     = {}
}

variable "api_load_balancer_type" {
  description = "Hetzner Load Balancer type used for the Kubernetes API."
  type        = string
  default     = "lb11"
}

variable "api_load_balancer_location" {
  description = "Location of the API Load Balancer. Defaults to the cluster location."
  type        = string
  default     = null
}
