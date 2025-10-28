output "cluster_name" {
  description = "Generated name of the cluster (includes random pet name)"
  value       = local.cluster_name
}

output "node_count" {
  description = "Number of nodes in the cluster"
  value       = var.node_count
}

output "server_type" {
  description = "Server type used for nodes"
  value       = var.server_type
}

output "datacenter" {
  description = "Datacenter location"
  value       = var.datacenter
}

output "public_ips" {
  description = "Public IP addresses of cluster nodes"
  value = {
    for server in hcloud_server.cluster_nodes :
    server.name => server.ipv4_address
  }
}

output "private_ips" {
  description = "Private IP addresses of cluster nodes"
  value = {
    for server in hcloud_server.cluster_nodes :
    server.name => server.network[0].ip
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to each node"
  value = {
    for server in hcloud_server.cluster_nodes :
    server.name => "ssh root@${server.ipv4_address}"
  }
}

output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.cluster_network.id
}

output "network_range" {
  description = "IP range of the private network"
  value       = hcloud_network.cluster_network.ip_range
}

output "firewall_id" {
  description = "ID of the firewall"
  value       = hcloud_firewall.cluster_firewall.id
}
