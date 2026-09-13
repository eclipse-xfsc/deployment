output "kubernetes_api_endpoint" {
  description = "Public Kubernetes API endpoint."

  value = (
    local.api_load_balancer_enabled
    ? "https://${hcloud_load_balancer.api[0].ipv4}:6443"
    : "https://${hcloud_server.control_plane[0].ipv4_address}:6443"
  )
}

output "load_balancer_ipv4" {
  description = "Public IPv4 address of the Kubernetes API load balancer, or null for a single control-plane node."

  value = (
    local.api_load_balancer_enabled
    ? hcloud_load_balancer.api[0].ipv4
    : null
  )
}

output "control_plane_public_ipv4" {
  description = "Public IPv4 addresses of the control-plane nodes."
  value       = [for server in hcloud_server.control_plane : try(server.ipv4_address, null)]
}

output "control_plane_private_ipv4" {
  description = "Private IPv4 addresses of the control-plane nodes."
  value       = local.control_plane_ips
}

output "worker_public_ipv4" {
  description = "Public IPv4 addresses of the worker nodes."
  value       = [for server in hcloud_server.worker : try(server.ipv4_address, null)]
}

output "worker_private_ipv4" {
  description = "Private IPv4 addresses of the worker nodes."
  value       = local.worker_ips
}

output "first_control_plane_ipv4" {
  description = "Public IPv4 address of the first control-plane node."
  value       = try(hcloud_server.control_plane[0].ipv4_address, null)
}

output "ssh_public_key_file" {
  description = "Path to the SSH public key used for the cluster."
  value       = var.ssh_public_key_file
}

output "get_kubeconfig_command" {
  description = "Command used to retrieve the K3s kubeconfig."
  value       = "./scripts/get-kubeconfig.sh"
}
