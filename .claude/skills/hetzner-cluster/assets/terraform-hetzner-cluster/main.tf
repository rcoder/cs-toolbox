# Generate a random pet name for the cluster
resource "random_pet" "cluster_name" {
  length    = 2
  separator = "-"
}

# Compute the full cluster name and location mapping
locals {
  # Cluster name with random pet suffix
  cluster_name = var.cluster_name != "" ? "${var.cluster_name}-${random_pet.cluster_name.id}" : random_pet.cluster_name.id

  # Map friendly datacenter names to Hetzner location codes
  location_map = {
    hillsboro  = "hil-dc1"   # Hillsboro, OR, USA
    singapore  = "sin-dc1"   # Singapore
    germany    = "fsn1-dc14" # Falkenstein, Germany
  }

  # Use explicit location if provided, otherwise derive from datacenter
  effective_location = var.location != "" ? var.location : local.location_map[var.datacenter]
}

# SSH Key
resource "hcloud_ssh_key" "cluster_key" {
  name       = "${local.cluster_name}-key"
  public_key = var.ssh_public_key
}

# Private Network for internal communication
resource "hcloud_network" "cluster_network" {
  name     = "${local.cluster_name}-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "cluster_subnet" {
  network_id   = hcloud_network.cluster_network.id
  type         = "cloud"
  network_zone = var.datacenter == "hillsboro" ? "us-west" : (var.datacenter == "singapore" ? "ap-southeast" : "eu-central")
  ip_range     = "10.0.1.0/24"
}

# Firewall rules: SSH (22), HTTPS (443), ZeroTier (9993/udp)
resource "hcloud_firewall" "cluster_firewall" {
  name = "${local.cluster_name}-firewall"

  # Allow SSH from anywhere
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow HTTPS from anywhere
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow ZeroTier UDP port 9993
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "9993"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow all traffic within the private network
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  rule {
    direction = "in"
    protocol  = "udp"
    port      = "any"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }
}

# Cluster nodes
resource "hcloud_server" "cluster_nodes" {
  count       = var.node_count
  name        = "${local.cluster_name}-${format("%02d", count.index + 1)}"
  server_type = var.server_type
  image       = var.image
  location    = local.effective_location
  ssh_keys    = [hcloud_ssh_key.cluster_key.id]
  firewall_ids = [hcloud_firewall.cluster_firewall.id]

  # Attach to private network
  network {
    network_id = hcloud_network.cluster_network.id
    ip         = "10.0.1.${count.index + 10}"
  }

  # Ensure network is created before servers
  depends_on = [hcloud_network_subnet.cluster_subnet]

  labels = {
    cluster = local.cluster_name
    role    = "node"
  }
}
