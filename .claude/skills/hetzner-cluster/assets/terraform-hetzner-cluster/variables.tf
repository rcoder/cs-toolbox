variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Optional prefix for cluster name (will be combined with random pet name, e.g., 'myapp-happy-turtle'). Leave empty for just the random name."
  type        = string
  default     = ""
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "server_type" {
  description = "Hetzner Cloud server type (CCX13, CCX23, or CCX33)"
  type        = string
  default     = "ccx13"

  validation {
    condition     = contains(["ccx13", "ccx23", "ccx33"], var.server_type)
    error_message = "Server type must be one of: ccx13, ccx23, ccx33."
  }
}

variable "datacenter" {
  description = "Hetzner datacenter location (hillsboro, singapore, or germany)"
  type        = string
  default     = "hillsboro"

  validation {
    condition     = contains(["hillsboro", "singapore", "germany"], var.datacenter)
    error_message = "Datacenter must be one of: hillsboro, singapore, germany."
  }
}

variable "location" {
  description = "Hetzner location code (auto-derived from datacenter)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key content for server access"
  type        = string
}

variable "image" {
  description = "OS image to use (default: Ubuntu LTS)"
  type        = string
  default     = "ubuntu-24.04"
}
