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
    hillsboro  = "hil"   # Hillsboro, OR, USA
    singapore  = "sin"   # Singapore
    germany    = "fsn1"  # Falkenstein, Germany
  }

  # Use explicit location if provided, otherwise derive from datacenter
  effective_location = var.location != "" ? var.location : local.location_map[var.datacenter]
}

# SSH Key
resource "hcloud_ssh_key" "cluster_key" {
  name       = "${local.cluster_name}-key"
  public_key = file("${var.ssh_private_key_path}.pub")
}

# Generate random second octet for ZeroTier network (10.X.0.0/16)
resource "random_integer" "zt_subnet" {
  min = 0
  max = 255
}

# ZeroTier Network
resource "zerotier_network" "cluster_network" {
  name        = "${local.cluster_name}-zt-network"
  description = "ZeroTier network for ${local.cluster_name} cluster"
  private     = true

  assignment_pool {
    start = "10.${random_integer.zt_subnet.result}.0.1"
    end   = "10.${random_integer.zt_subnet.result}.0.254"
  }

  route {
    target = "10.${random_integer.zt_subnet.result}.0.0/24"
  }
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

  # SSH connection for provisioners
  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = file(var.ssh_private_key_path)
  }

  # Install ZeroTier
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Installing ZeroTier...'",
      "curl -s https://install.zerotier.com | bash",
      "echo 'ZeroTier installed successfully'"
    ]
  }

  # Wait for ZeroTier service to start and generate identity
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Waiting for ZeroTier service to start...'",
      "sleep 5",
      "systemctl status zerotier-one --no-pager || true",
      "echo 'ZeroTier service is running'"
    ]
  }

  # Join the ZeroTier network
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Joining ZeroTier network ${zerotier_network.cluster_network.id}...'",
      "zerotier-cli join ${zerotier_network.cluster_network.id}",
      "echo 'Join request sent to network'"
    ]
  }

  # Output the node's ZeroTier ID to a local file for later retrieval
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} root@${self.ipv4_address} 'zerotier-cli info' | awk '{print $3}' > zt_node_${count.index}.txt"
  }
}

# Read ZeroTier node IDs from local files
data "local_file" "zt_node_ids" {
  count      = var.node_count
  filename   = "${path.module}/zt_node_${count.index}.txt"
  depends_on = [hcloud_server.cluster_nodes]
}

# Authorize nodes on the ZeroTier network
resource "zerotier_member" "cluster_members" {
  count      = var.node_count
  name       = "${local.cluster_name}-${format("%02d", count.index + 1)}"
  member_id  = trimspace(data.local_file.zt_node_ids[count.index].content)
  network_id = zerotier_network.cluster_network.id
  authorized = true

  depends_on = [data.local_file.zt_node_ids]
}
