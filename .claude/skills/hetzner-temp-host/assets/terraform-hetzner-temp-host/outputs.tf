# Host Information
output "host_name" {
  description = "Name of the temporary host"
  value       = local.generated_name
}

output "host_id" {
  description = "Hetzner Cloud server ID"
  value       = hcloud_server.temp_host.id
}

output "server_type" {
  description = "Server type used"
  value       = hcloud_server.temp_host.server_type
}

output "location" {
  description = "Datacenter location"
  value       = hcloud_server.temp_host.location
}

# Network Information
output "public_ip" {
  description = "Public IPv4 address"
  value       = hcloud_server.temp_host.ipv4_address
}

output "public_ipv6" {
  description = "Public IPv6 address"
  value       = hcloud_server.temp_host.ipv6_address
}

# SSH Access
output "ssh_command" {
  description = "SSH command to connect to the host"
  value       = "ssh root@${hcloud_server.temp_host.ipv4_address}"
}

# ZeroTier Information
output "zerotier_network_id" {
  description = "ZeroTier network ID the host joined"
  value       = var.zerotier_network
}

output "zerotier_info_command" {
  description = "Command to get ZeroTier node information"
  value       = "ssh root@${hcloud_server.temp_host.ipv4_address} 'zerotier-cli info && zerotier-cli listnetworks'"
}

output "zerotier_node_id" {
  description = "ZeroTier node ID (retrieve after deployment)"
  value       = "Run: ssh root@${hcloud_server.temp_host.ipv4_address} \"zerotier-cli info | cut -d' ' -f3\""
}

# Service Information
output "repository" {
  description = "GitHub repository deployed"
  value       = var.github_repo_url
}

output "branch" {
  description = "Git branch deployed"
  value       = var.github_branch
}

output "app_directory" {
  description = "Application directory on host"
  value       = "/opt/app"
}

# Docker Commands
output "docker_status_command" {
  description = "Command to check Docker Compose status"
  value       = "ssh root@${hcloud_server.temp_host.ipv4_address} 'docker compose -f /opt/app/${var.docker_compose_file} ps'"
}

output "docker_logs_command" {
  description = "Command to view Docker Compose logs"
  value       = "ssh root@${hcloud_server.temp_host.ipv4_address} 'docker compose -f /opt/app/${var.docker_compose_file} logs -f'"
}

output "docker_restart_command" {
  description = "Command to restart Docker Compose services"
  value       = "ssh root@${hcloud_server.temp_host.ipv4_address} 'docker compose -f /opt/app/${var.docker_compose_file} restart'"
}

# Service URLs
output "service_url_http" {
  description = "HTTP URL to access service (adjust port as needed)"
  value       = "http://${hcloud_server.temp_host.ipv4_address}:80"
}

output "service_url_https" {
  description = "HTTPS URL to access service (adjust port as needed)"
  value       = "https://${hcloud_server.temp_host.ipv4_address}:443"
}

# Cost Information
output "estimated_cost_hourly" {
  description = "Estimated hourly cost (USD)"
  value = var.server_type == "ccx13" ? "$0.012/hour" : (
    var.server_type == "ccx23" ? "$0.025/hour" : "$0.049/hour"
  )
}

output "estimated_cost_daily" {
  description = "Estimated daily cost (USD)"
  value = var.server_type == "ccx13" ? "$0.29/day" : (
    var.server_type == "ccx23" ? "$0.59/day" : "$1.18/day"
  )
}

# Deployment Status
output "deployment_info" {
  description = "Summary of deployment"
  value = {
    host_name     = local.generated_name
    public_ip     = hcloud_server.temp_host.ipv4_address
    repository    = var.github_repo_url
    branch        = var.github_branch
    zerotier_net  = var.zerotier_network
    health_checks = var.health_check_enabled ? "enabled" : "disabled"
  }
}

# Quick Start Commands
output "quick_commands" {
  description = "Quick reference commands"
  value = {
    ssh            = "ssh root@${hcloud_server.temp_host.ipv4_address}"
    docker_status  = "ssh root@${hcloud_server.temp_host.ipv4_address} 'docker compose -f /opt/app/${var.docker_compose_file} ps'"
    docker_logs    = "ssh root@${hcloud_server.temp_host.ipv4_address} 'docker compose -f /opt/app/${var.docker_compose_file} logs -f'"
    zerotier_info  = "ssh root@${hcloud_server.temp_host.ipv4_address} 'zerotier-cli listnetworks'"
    destroy        = "terraform destroy"
  }
}

# Reminder
output "reminder" {
  description = "Important reminder"
  value       = "Remember to run 'terraform destroy' when you're done to avoid unnecessary costs!"
}
