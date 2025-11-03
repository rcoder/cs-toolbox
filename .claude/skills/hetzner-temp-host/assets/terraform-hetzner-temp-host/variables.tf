variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.hcloud_token) > 0
    error_message = "Hetzner Cloud API token must be provided. Get one at https://console.hetzner.cloud/"
  }
}

variable "zerotier_api_token" {
  description = "ZeroTier Central API token for network authorization"
  type        = string
  sensitive   = true
  default     = ""
}

variable "zerotier_network" {
  description = "ZeroTier network ID to join (16-character hex string)"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{16}$", var.zerotier_network))
    error_message = "ZeroTier network ID must be a 16-character hexadecimal string."
  }
}

variable "host_name" {
  description = "Name for the temporary host (leave empty for random name)"
  type        = string
  default     = ""

  validation {
    condition     = var.host_name == "" || can(regex("^[a-z0-9-]+$", var.host_name))
    error_message = "Host name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "github_repo_url" {
  description = "GitHub repository URL to clone and deploy"
  type        = string

  validation {
    condition     = can(regex("^https://github\\.com/[^/]+/[^/]+(\\.git)?$", var.github_repo_url))
    error_message = "Must be a valid GitHub HTTPS URL (e.g., https://github.com/user/repo or https://github.com/user/repo.git)"
  }
}

variable "github_branch" {
  description = "Git branch to checkout (defaults to main)"
  type        = string
  default     = "main"

  validation {
    condition     = length(var.github_branch) > 0
    error_message = "Branch name cannot be empty."
  }
}

variable "server_type" {
  description = "Hetzner server type (CCX line recommended for best performance)"
  type        = string
  default     = "ccx13"

  validation {
    condition     = contains(["ccx13", "ccx23", "ccx33"], var.server_type)
    error_message = "Server type must be one of: ccx13, ccx23, ccx33"
  }
}

variable "datacenter" {
  description = "Datacenter location (hillsboro, singapore, or germany)"
  type        = string
  default     = "hillsboro"

  validation {
    condition     = contains(["hillsboro", "singapore", "germany"], var.datacenter)
    error_message = "Datacenter must be one of: hillsboro, singapore, germany"
  }
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for connecting to the server"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "health_check_enabled" {
  description = "Enable health checks after deployment"
  type        = bool
  default     = true
}

variable "health_check_url" {
  description = "HTTP(S) endpoint to check for service health (optional)"
  type        = string
  default     = ""

  validation {
    condition     = var.health_check_url == "" || can(regex("^https?://", var.health_check_url))
    error_message = "Health check URL must be empty or start with http:// or https://"
  }
}

variable "docker_compose_file" {
  description = "Name of Docker Compose file in repository (docker-compose.yml or compose.yaml)"
  type        = string
  default     = "docker-compose.yml"

  validation {
    condition     = contains(["docker-compose.yml", "compose.yaml"], var.docker_compose_file)
    error_message = "Docker Compose file must be either docker-compose.yml or compose.yaml"
  }
}

variable "additional_ssh_keys" {
  description = "Additional SSH public keys to add to the host (list of key content)"
  type        = list(string)
  default     = []
}

# Datacenter to location mapping
locals {
  datacenter_map = {
    hillsboro = "hil-dc1"
    singapore = "sin-dc1"
    germany   = "fsn1-dc14"
  }

  location = local.datacenter_map[var.datacenter]

  # Generate random name if not provided
  generated_name = var.host_name != "" ? var.host_name : "${random_pet.host_name[0].id}"

  # Expanded SSH private key path
  ssh_key_path = pathexpand(var.ssh_private_key_path)
  ssh_pub_key_path = "${local.ssh_key_path}.pub"
}

# Random name generator (used if host_name is empty)
resource "random_pet" "host_name" {
  count     = var.host_name == "" ? 1 : 0
  length    = 2
  separator = "-"
}
