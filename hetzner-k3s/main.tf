locals {
  common_labels = merge(var.labels, {
    cluster      = var.cluster_name
    "managed-by" = "terraform"
  })
  k3s_token = coalesce(
    var.cluster_token,
    random_password.k3s_token.result
  )
  # A dedicated Kubernetes API load balancer is useful for an HA control plane.
  api_load_balancer_enabled = var.control_plane_count > 1
  control_plane_ips = [
    for index in range(var.control_plane_count) :
    cidrhost(
      var.subnet_cidr,
      var.control_plane_start_ip + index
    )
  ]
  worker_ips = [
    for index in range(var.worker_count) :
    cidrhost(
      var.subnet_cidr,
      var.worker_start_ip + index
    )
  ]
  k3s_disable_flags = join(" ", compact([
    var.disable_traefik   ? "--disable=traefik" : "",
    var.disable_servicelb ? "--disable=servicelb" : ""
  ]))
  # Public Kubernetes API load-balancer address.
  #
  # This value exists only for an HA control plane.
  api_load_balancer_address = (
    local.api_load_balancer_enabled
    ? hcloud_load_balancer.api[0].ipv4
    : null
  )
  # Public address of the first control-plane node for a single-node
  # control plane.
  #
  # The Primary IP is created independently from the server. Therefore its
  # address can safely be used while rendering the server's cloud-init
  # template without creating a dependency cycle.
  single_control_plane_public_address = (
    !local.api_load_balancer_enabled &&
    var.enable_controlplane_public_ipv4
    ? hcloud_primary_ip.control_plane_ipv4[0].ip_address
    : null
  )
  # Kubernetes API TLS SAN selection:
  #
  # 1. Explicit api_tls_san
  # 2. Public API load-balancer address for HA
  # 3. Public Primary IPv4 of the first control-plane node
  # 4. Private IP of the first control-plane node
  api_tls_san = coalesce(
    trimspace(var.api_tls_san) != ""
    ? trimspace(var.api_tls_san)
    : null,
    local.api_load_balancer_address,
    local.single_control_plane_public_address,
    local.control_plane_ips[0]
  )
}
# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
check "control_plane_count_is_positive" {
  assert {
    condition     = var.control_plane_count >= 1
    error_message = "control_plane_count must be at least 1."
  }
}
check "private_ip_ranges_do_not_overlap" {
  assert {
    condition = length(
      setintersection(
        toset(local.control_plane_ips),
        toset(local.worker_ips)
      )
    ) == 0
    error_message = "The control-plane and worker private IP ranges overlap."
  }
}
check "control_plane_ips_fit_subnet" {
  assert {
    condition = alltrue([
      for index in range(var.control_plane_count) :
      can(cidrhost(
        var.subnet_cidr,
        var.control_plane_start_ip + index
      ))
    ])
    error_message = "The configured control-plane IP range does not fit into subnet_cidr."
  }
}
check "worker_ips_fit_subnet" {
  assert {
    condition = alltrue([
      for index in range(var.worker_count) :
      can(cidrhost(
        var.subnet_cidr,
        var.worker_start_ip + index
      ))
    ])
    error_message = "The configured worker IP range does not fit into subnet_cidr."
  }
}
check "public_api_endpoint_is_available" {
  assert {
    condition = (
      trimspace(var.api_tls_san) != "" ||
      local.api_load_balancer_enabled ||
      var.enable_controlplane_public_ipv4
    )
    error_message = <<-EOT
      No public Kubernetes API endpoint is available.
      Configure at least one of:
      - api_tls_san
      - enable_controlplane_public_ipv4 = true
      - control_plane_count > 1
    EOT
  }
}
# -----------------------------------------------------------------------------
# K3s cluster token
# -----------------------------------------------------------------------------
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}
# -----------------------------------------------------------------------------
# SSH key
# -----------------------------------------------------------------------------
resource "hcloud_ssh_key" "cluster" {
  name       = "${var.cluster_name}-key"
  public_key = file(var.ssh_public_key_file)
  labels = local.common_labels
}
# -----------------------------------------------------------------------------
# Private network
# -----------------------------------------------------------------------------
resource "hcloud_network" "cluster" {
  name     = "${var.cluster_name}-network"
  ip_range = var.network_cidr
  labels   = local.common_labels
}
resource "hcloud_network_subnet" "cluster" {
  network_id   = hcloud_network.cluster.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}
# -----------------------------------------------------------------------------
# Firewall
# -----------------------------------------------------------------------------
resource "hcloud_firewall" "cluster" {
  name   = "${var.cluster_name}-firewall"
  labels = local.common_labels
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.ssh_allowed_cidrs
    description = "SSH administration"
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = distinct(concat(
      var.kubernetes_api_allowed_cidrs,
      [var.subnet_cidr]
    ))
    description = "Kubernetes API and internal K3s registration"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2379-2380"
    source_ips  = [var.subnet_cidr]
    description = "Embedded etcd communication"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "10250"
    source_ips  = [var.subnet_cidr]
    description = "Kubelet API, metrics, logs and exec"
  }
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "8472"
    source_ips  = [var.subnet_cidr]
    description = "Flannel VXLAN"
  }
  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = [var.subnet_cidr]
    description = "Internal network diagnostics"
  }
}
# -----------------------------------------------------------------------------
# Kubernetes API load balancer
#
# Created automatically when control_plane_count is greater than one.
# This load balancer is separate from application LoadBalancer services that
# will later be managed by the Hetzner Cloud Controller Manager.
# -----------------------------------------------------------------------------
resource "hcloud_load_balancer" "api" {
  count = local.api_load_balancer_enabled ? 1 : 0
  name               = "${var.cluster_name}-api"
  load_balancer_type = var.api_load_balancer_type
  location = coalesce(
    var.api_load_balancer_location,
    var.location
  )
  labels = local.common_labels
  algorithm {
    type = "round_robin"
  }
}
resource "hcloud_load_balancer_network" "api" {
  count = local.api_load_balancer_enabled ? 1 : 0
  load_balancer_id        = hcloud_load_balancer.api[0].id
  subnet_id               = hcloud_network_subnet.cluster.id
  enable_public_interface = true
}
resource "hcloud_load_balancer_service" "kubernetes_api" {
  count = local.api_load_balancer_enabled ? 1 : 0
  load_balancer_id = hcloud_load_balancer.api[0].id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
  health_check {
    protocol = "tcp"
    port     = 6443
    interval = 10
    timeout  = 5
    retries  = 3
  }
}
resource "hcloud_load_balancer_target" "control_planes" {
  count = local.api_load_balancer_enabled ? 1 : 0
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.api[0].id
  use_private_ip   = true
  label_selector = "cluster=${var.cluster_name},role=control-plane"
  depends_on = [
    hcloud_load_balancer_network.api
  ]
}
# -----------------------------------------------------------------------------
# Placement groups
# -----------------------------------------------------------------------------
resource "hcloud_placement_group" "control_plane" {
  count = var.control_plane_count > 1 ? 1 : 0
  name   = "${var.cluster_name}-control-plane"
  type   = "spread"
  labels = local.common_labels
}
resource "hcloud_placement_group" "workers" {
  count = var.worker_count > 1 ? 1 : 0
  name   = "${var.cluster_name}-workers"
  type   = "spread"
  labels = local.common_labels
}
# -----------------------------------------------------------------------------
# Control-plane public Primary IPv4 addresses
#
# The Primary IPs are created before the control-plane servers. This makes
# their public addresses available while rendering cloud-init and prevents
# a dependency cycle through hcloud_server.control_plane.user_data.
# -----------------------------------------------------------------------------
resource "hcloud_primary_ip" "control_plane_ipv4" {
  count = (
    var.enable_controlplane_public_ipv4
    ? var.control_plane_count
    : 0
  )
  name = format(
    "%s-control-%02d-ipv4",
    var.cluster_name,
    count.index + 1
  )
  type        = "ipv4"
  location    = var.location
  auto_delete = false
  labels = merge(local.common_labels, {
    role = "control-plane"
    node = format(
      "%s-control-%02d",
      var.cluster_name,
      count.index + 1
    )
  })
}
# -----------------------------------------------------------------------------
# Control-plane nodes
# -----------------------------------------------------------------------------
resource "hcloud_server" "control_plane" {
  count = var.control_plane_count
  name = format(
    "%s-control-plane-%02d",
    var.cluster_name,
    count.index + 1
  )
  image       = var.image
  server_type = var.control_plane_server_type
  location    = var.location
  ssh_keys     = [hcloud_ssh_key.cluster.id]
  firewall_ids = [hcloud_firewall.cluster.id]
  placement_group_id = (
    var.control_plane_count > 1
    ? hcloud_placement_group.control_plane[0].id
    : null
  )
  backups = var.enable_backups
  labels = merge(local.common_labels, {
    role = "control-plane"
  })
  public_net {
    ipv4 = (
      var.enable_controlplane_public_ipv4
      ? hcloud_primary_ip.control_plane_ipv4[count.index].id
      : null
    )
    ipv4_enabled = var.enable_controlplane_public_ipv4
    ipv6_enabled = var.enable_controlplane_public_ipv6
  }
  network {
    network_id = hcloud_network.cluster.id
    ip         = local.control_plane_ips[count.index]
  }
  user_data = templatefile(
    "${path.module}/templates/control-plane.yaml.tftpl",
    {
      node_name = format(
        "%s-control-plane-%02d",
        var.cluster_name,
        count.index + 1
      )
      node_ip         = local.control_plane_ips[count.index]
      first_server_ip = local.control_plane_ips[0]
      cluster_token = local.k3s_token
      k3s_version   = var.k3s_version
      cluster_init  = count.index == 0
      disable_flags = local.k3s_disable_flags
      api_tls_san   = local.api_tls_san
    }
  )
  depends_on = [
    hcloud_network_subnet.cluster,
    hcloud_load_balancer_network.api
  ]
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}
# -----------------------------------------------------------------------------
# Worker nodes
# -----------------------------------------------------------------------------
resource "hcloud_server" "worker" {
  count = var.worker_count
  name = format(
    "%s-worker-%02d",
    var.cluster_name,
    count.index + 1
  )
  image       = var.image
  server_type = var.worker_server_type
  location    = var.location
  ssh_keys     = [hcloud_ssh_key.cluster.id]
  firewall_ids = [hcloud_firewall.cluster.id]
  placement_group_id = (
    var.worker_count > 1
    ? hcloud_placement_group.workers[0].id
    : null
  )
  backups = var.enable_backups
  labels = merge(local.common_labels, {
    role = "worker"
  })
  public_net {
    ipv4_enabled = var.enable_worker_public_ipv4
    ipv6_enabled = var.enable_worker_public_ipv6
  }
  network {
    network_id = hcloud_network.cluster.id
    ip         = local.worker_ips[count.index]
  }
  user_data = templatefile(
    "${path.module}/templates/worker.yaml.tftpl",
    {
      node_name = format(
        "%s-worker-%02d",
        var.cluster_name,
        count.index + 1
      )
      node_ip         = local.worker_ips[count.index]
      first_server_ip = local.control_plane_ips[0]
      cluster_token   = local.k3s_token
      k3s_version     = var.k3s_version
    }
  )
  depends_on = [
    hcloud_network_subnet.cluster,
    hcloud_server.control_plane
  ]
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}