---
name: hetzner-cluster
description: Toolkit for creating and managing server clusters on Hetzner Cloud using Terraform. Use this skill when users request deploying VMs, creating test infrastructure, or setting up server clusters on Hetzner Cloud. The skill provides Terraform templates optimized for network testing with strict firewall rules, public and private network interfaces, and support for ZeroTier VPN.
---

# Hetzner Cluster

## Overview

Create and manage VM clusters on Hetzner Cloud using Terraform templates optimized for hands-on testing and network experimentation. The skill provides pre-configured Terraform templates with secure networking (public + private interfaces), strict firewall rules (SSH, HTTPS, ZeroTier), and support for multiple datacenters.

## When to Use This Skill

Use this skill when users request:
- Creating server clusters on Hetzner Cloud
- Deploying VMs for testing or development
- Setting up infrastructure for network testing
- Provisioning servers with specific network configurations
- Creating cost-effective cloud infrastructure

## Quick Start

To deploy a cluster:

1. **Copy the Terraform template** from `assets/terraform-hetzner-cluster/` to the user's working directory
2. **Get SSH public key** using `scripts/get_ssh_key.py`
3. **Create configuration** either manually or using `scripts/deploy_cluster.sh`
4. **Deploy** with `terraform init`, `terraform plan`, and `terraform apply`

## Core Capabilities

### 1. Cluster Configuration

The Terraform templates support flexible cluster configurations:

**Server Types (CCX Line):**
- `ccx13`: 2 vCPU, 8GB RAM, 80GB NVMe (~$8.90/month)
- `ccx23`: 4 vCPU, 16GB RAM, 160GB NVMe (~$17.80/month)
- `ccx33`: 8 vCPU, 32GB RAM, 240GB NVMe (~$35.60/month)

**Datacenters:**
- `hillsboro`: Hillsboro, OR, USA (hil-dc1) - Default
- `singapore`: Singapore (sin-dc1)
- `germany`: Falkenstein, Germany (fsn1-dc14)

**Node Count:**
- Default: 3 nodes
- Range: 1-10 nodes
- Customizable per deployment

**Example Configuration:**
```hcl
cluster_name   = "test-cluster"
node_count     = 3
server_type    = "ccx13"
datacenter     = "hillsboro"
```

### 2. Network Architecture

Each cluster includes:

**Public Interface:**
- Public IPv4 address per node
- IPv6 /64 subnet
- Protected by strict firewall rules

**Private Network:**
- 10.0.0.0/16 private network range
- 10.0.1.0/24 subnet for cluster nodes
- Static IP assignment (10.0.1.10, 10.0.1.11, etc.)
- Unrestricted inter-node communication

**Firewall Rules:**
- **Inbound (public)**: SSH (22), HTTPS (443), ZeroTier (9993/UDP)
- **Inbound (private)**: All TCP, UDP, and ICMP from 10.0.0.0/16
- **Outbound**: All traffic allowed

Refer to `references/network-config.md` for detailed network specifications.

### 3. Deployment Methods

**Method A: Using the Helper Script (Recommended)**

The `scripts/deploy_cluster.sh` script automates the entire deployment process:

```bash
# Copy script to working directory
cp scripts/deploy_cluster.sh .
chmod +x deploy_cluster.sh

# Set Hetzner API token
export HCLOUD_TOKEN='your-token-here'

# Deploy with defaults (3 nodes, ccx13, hillsboro)
./deploy_cluster.sh my-cluster

# Deploy with custom configuration
./deploy_cluster.sh prod-cluster 5 ccx23 singapore
```

The script will:
1. Find SSH public key automatically
2. Generate `terraform.tfvars`
3. Initialize Terraform
4. Show plan and prompt for confirmation
5. Deploy cluster
6. Display connection information

**Method B: Manual Deployment**

For more control or customization:

1. **Copy Terraform templates:**
   ```bash
   cp -r assets/terraform-hetzner-cluster/* ./
   ```

2. **Find SSH public key:**
   ```bash
   python3 scripts/get_ssh_key.py
   ```

3. **Create terraform.tfvars:**
   ```hcl
   hcloud_token   = "your-hetzner-api-token"
   cluster_name   = "test-cluster"
   node_count     = 3
   server_type    = "ccx13"
   datacenter     = "hillsboro"
   ssh_public_key = "ssh-ed25519 AAAAC3... user@host"
   ```

4. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. **View outputs:**
   ```bash
   terraform output
   ```

### 4. Accessing Cluster Nodes

After deployment, Terraform outputs provide connection details:

**View all outputs:**
```bash
terraform output
```

**Get SSH commands:**
```bash
terraform output -json ssh_commands | jq -r '.[]'
```

**Example output:**
```
ssh root@<public-ip-1>
ssh root@<public-ip-2>
ssh root@<public-ip-3>
```

**View IP addresses:**
```bash
# Public IPs
terraform output public_ips

# Private IPs
terraform output private_ips
```

### 5. Cluster Management

**View cluster status:**
```bash
terraform show
```

**Modify cluster:**
1. Edit `terraform.tfvars` (e.g., change node_count)
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

**Destroy cluster:**
```bash
terraform destroy
```

**Note:** Always destroy test clusters when done to avoid unnecessary costs.

## Common Workflows

### Workflow 1: Create a Basic Test Cluster

User request: *"Create a 3-node test cluster on Hetzner"*

1. Copy Terraform templates to current directory
2. Run `scripts/get_ssh_key.py` to get SSH public key
3. Use `scripts/deploy_cluster.sh` with defaults or create `terraform.tfvars` manually
4. Deploy with `terraform apply`
5. Provide SSH commands from outputs

### Workflow 2: Create a Multi-Region Cluster

User request: *"Set up clusters in both Singapore and Germany for latency testing"*

1. Create two separate directories (e.g., `cluster-singapore/`, `cluster-germany/`)
2. Copy Terraform templates to each directory
3. Configure each with appropriate datacenter:
   - `cluster-singapore/terraform.tfvars`: `datacenter = "singapore"`
   - `cluster-germany/terraform.tfvars`: `datacenter = "germany"`
4. Deploy each cluster independently
5. Provide connection details for both clusters

### Workflow 3: Create a Larger Cluster with More Resources

User request: *"I need a 5-node cluster with more powerful servers for performance testing"*

1. Copy Terraform templates
2. Configure with increased resources:
   ```hcl
   node_count  = 5
   server_type = "ccx23"  # 4 vCPU, 16GB RAM
   ```
3. Deploy and provide connection details

### Workflow 4: Cluster with ZeroTier Setup

User request: *"Create a cluster that I can connect to via ZeroTier"*

1. Deploy cluster using standard workflow
2. Note that port 9993/UDP is already open in firewall
3. After deployment, provide instructions to:
   - Install ZeroTier on each node: `curl -s https://install.zerotier.com | sudo bash`
   - Join ZeroTier network: `zerotier-cli join <network-id>`
4. User can then access nodes via ZeroTier IPs

## Reference Material

Detailed specifications and documentation are available in the `references/` directory:

- **`references/hetzner-specs.md`**: Complete server type specifications, datacenter details, and pricing information
- **`references/network-config.md`**: Detailed network architecture, firewall rules, and connectivity options

Load these references when users need detailed information about:
- Server type selection and specifications
- Datacenter locations and network zones
- Network configuration details
- Firewall rule explanations

## Troubleshooting

**SSH key not found:**
- Ensure `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub` exists
- Generate new key: `ssh-keygen -t ed25519 -C "user@example.com"`

**HCLOUD_TOKEN not set:**
- Get token from https://console.hetzner.cloud/
- Export as environment variable: `export HCLOUD_TOKEN='your-token'`

**Terraform errors:**
- Ensure Terraform >= 1.0 is installed
- Run `terraform init` in the correct directory
- Check API token has appropriate permissions

**Invalid datacenter/location:**
- Use only supported datacenters: hillsboro, singapore, germany
- Location codes are auto-derived from datacenter selection

**Network zone mismatch:**
- Private networks must be in the same network zone
- Don't mix servers from different zones in one cluster

## Resources

### scripts/
- `get_ssh_key.py`: Finds and returns SSH public key from ~/.ssh/ (prioritizes Ed25519)
- `deploy_cluster.sh`: Complete deployment automation script with interactive prompts

### references/
- `hetzner-specs.md`: Server specifications, datacenter locations, and pricing
- `network-config.md`: Network architecture, firewall rules, and connectivity details

### assets/
- `terraform-hetzner-cluster/`: Complete Terraform templates ready for deployment
  - `main.tf`: Core infrastructure (servers, networks, firewalls)
  - `variables.tf`: Input variables with validation and defaults
  - `outputs.tf`: Connection information and cluster details
  - `versions.tf`: Terraform and provider version requirements
  - `terraform.tfvars.example`: Example configuration file
