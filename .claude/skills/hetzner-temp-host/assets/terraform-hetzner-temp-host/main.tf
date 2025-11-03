terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key
resource "hcloud_ssh_key" "host_key" {
  name       = "${local.generated_name}-key"
  public_key = file(local.ssh_pub_key_path)
}

# Firewall rules: SSH (22), HTTP (80), HTTPS (443), ZeroTier (9993/udp)
resource "hcloud_firewall" "host_firewall" {
  name = "${local.generated_name}-firewall"

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

  # Allow HTTP from anywhere (for web services)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
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

  # Allow custom ports 3000-9000 (common for dev services)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "3000-9000"
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
}

# Temporary Host Server
resource "hcloud_server" "temp_host" {
  name        = local.generated_name
  server_type = var.server_type
  location    = local.location
  image       = "ubuntu-24.04"

  ssh_keys = concat(
    [hcloud_ssh_key.host_key.id],
    var.additional_ssh_keys
  )

  firewall_ids = [hcloud_firewall.host_firewall.id]

  labels = {
    purpose     = "temporary-deployment"
    managed_by  = "terraform"
    auto_deploy = "true"
  }

  # Wait for server to be fully ready
  provisioner "remote-exec" {
    inline = ["echo 'Server is ready'"]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(local.ssh_key_path)
      host        = self.ipv4_address
      timeout     = "5m"
    }
  }
}

# Install Docker, Docker Compose, and ZeroTier
resource "null_resource" "install_dependencies" {
  depends_on = [hcloud_server.temp_host]

  triggers = {
    server_id = hcloud_server.temp_host.id
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(local.ssh_key_path)
    host        = hcloud_server.temp_host.ipv4_address
    timeout     = "10m"
  }

  # Install Docker, Docker Compose, Git, and ZeroTier
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== Updating system packages ==='",
      "apt-get update -qq",
      "apt-get install -y -qq curl git ca-certificates gnupg lsb-release",

      "echo '=== Installing Docker ==='",
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt-get update -qq",
      "apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "systemctl enable docker",
      "systemctl start docker",

      "echo '=== Installing ZeroTier ==='",
      "curl -s https://install.zerotier.com | bash",

      "echo '=== Verifying installations ==='",
      "docker --version",
      "docker compose version",
      "zerotier-cli --version",
      "git --version",

      "echo '=== Dependencies installed successfully ==='",
    ]
  }
}

# Join ZeroTier network
resource "null_resource" "join_zerotier" {
  depends_on = [null_resource.install_dependencies]

  triggers = {
    server_id        = hcloud_server.temp_host.id
    zerotier_network = var.zerotier_network
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(local.ssh_key_path)
    host        = hcloud_server.temp_host.ipv4_address
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== Joining ZeroTier network ${var.zerotier_network} ==='",

      # Wait for ZeroTier service to be ready
      "sleep 5",
      "until systemctl is-active --quiet zerotier-one; do echo 'Waiting for ZeroTier service...'; sleep 2; done",

      # Join the network
      "zerotier-cli join ${var.zerotier_network}",

      # Wait a moment for join to register
      "sleep 5",

      # Get node ID
      "ZT_NODE_ID=$(zerotier-cli info | cut -d' ' -f3)",
      "echo \"ZeroTier Node ID: $ZT_NODE_ID\"",

      # Show network status
      "zerotier-cli listnetworks",

      "echo '=== ZeroTier join complete ==='",
      "echo 'Note: You may need to authorize this node at https://my.zerotier.com'",
    ]
  }
}

# Clone repository and deploy service
resource "null_resource" "deploy_service" {
  depends_on = [null_resource.join_zerotier]

  triggers = {
    server_id       = hcloud_server.temp_host.id
    github_repo_url = var.github_repo_url
    github_branch   = var.github_branch
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(local.ssh_key_path)
    host        = hcloud_server.temp_host.ipv4_address
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== Cloning repository ==='",
      "mkdir -p /opt/app",
      "cd /opt",

      # Clone the repository
      "git clone ${var.github_repo_url} app",
      "cd app",

      # Checkout specific branch if not main
      "git checkout ${var.github_branch}",

      "echo '=== Repository cloned: ${var.github_repo_url} (branch: ${var.github_branch}) ==='",
      "pwd",
      "ls -la",

      # Check if compose file exists
      "if [ ! -f ${var.docker_compose_file} ]; then",
      "  echo 'ERROR: ${var.docker_compose_file} not found in repository!'",
      "  exit 1",
      "fi",

      "echo '=== Starting Docker Compose services ==='",
      "docker compose -f ${var.docker_compose_file} up -d",

      # Wait for containers to start
      "sleep 10",

      "echo '=== Deployment complete ==='",
      "docker compose ps",
    ]
  }
}

# Run health checks if enabled
resource "null_resource" "health_check" {
  count      = var.health_check_enabled ? 1 : 0
  depends_on = [null_resource.deploy_service]

  triggers = {
    server_id         = hcloud_server.temp_host.id
    health_check_url  = var.health_check_url
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(local.ssh_key_path)
    host        = hcloud_server.temp_host.ipv4_address
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "set -e",
        "echo '=== Running health checks ==='",

        # Check Docker is running
        "echo 'Checking Docker status...'",
        "systemctl is-active docker",

        # Check containers are running
        "echo 'Checking containers...'",
        "cd /opt/app",
        "RUNNING=$(docker compose ps --format json | jq -r '.State' | grep -c 'running' || echo '0')",
        "TOTAL=$(docker compose ps --format json | jq -r '.State' | wc -l)",
        "echo \"Containers running: $RUNNING/$TOTAL\"",

        # Check ZeroTier connection
        "echo 'Checking ZeroTier connection...'",
        "zerotier-cli listnetworks | grep -q ${var.zerotier_network} && echo 'ZeroTier: Connected' || echo 'ZeroTier: Not connected'",
      ],
      var.health_check_url != "" ? [
        "",
        "# Check HTTP endpoint if provided",
        "echo 'Checking health endpoint: ${var.health_check_url}'",
        "sleep 5",  # Give service a moment to be ready
        "for i in {1..12}; do",
        "  if curl -f -s -o /dev/null ${var.health_check_url}; then",
        "    echo 'Health endpoint responding: OK'",
        "    break",
        "  else",
        "    echo \"Attempt $i/12: Health endpoint not ready yet...\"",
        "    if [ $i -eq 12 ]; then",
        "      echo 'WARNING: Health endpoint did not respond after 60 seconds'",
        "    fi",
        "    sleep 5",
        "  fi",
        "done",
      ] : [],
      [
        "",
        "echo '=== Health checks complete ==='",
      ]
    )
  }
}
