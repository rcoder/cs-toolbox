# Hetzner Temporary Host - Terraform Configuration

Deploy services from GitHub repositories to temporary Hetzner Cloud hosts with automatic ZeroTier network integration.

## Quick Start

### Prerequisites

- Hetzner Cloud API token ([get one here](https://console.hetzner.cloud/))
- ZeroTier network ID ([create at my.zerotier.com](https://my.zerotier.com))
- ZeroTier API token (optional, for auto-authorization)
- SSH key pair at `~/.ssh/id_ed25519` (or custom path)
- GitHub repository with `docker-compose.yml`

### Option 1: Automated Deployment (Recommended)

```bash
# Set environment variables
export HCLOUD_TOKEN='your-hetzner-token'
export ZEROTIER_NETWORK_ID='your-network-id'
export ZEROTIER_API_TOKEN='your-zerotier-token'  # optional

# Run deployment script
../../scripts/deploy_host.sh https://github.com/user/repo
```

### Option 2: Manual Deployment

```bash
# 1. Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your values
nano terraform.tfvars

# 3. Initialize and deploy
terraform init
terraform plan
terraform apply
```

## Configuration

See `terraform.tfvars.example` for all available options:

- **Required**: `hcloud_token`, `zerotier_network`, `github_repo_url`
- **Optional**: `github_branch`, `host_name`, `server_type`, `datacenter`, `health_check_url`

## After Deployment

```bash
# View all outputs
terraform output

# SSH to host
terraform output -raw ssh_command | sh

# Check Docker status
terraform output -raw docker_status_command | sh

# View logs
terraform output -raw docker_logs_command | sh

# Check health
../../scripts/check_health.sh $(terraform output -raw public_ip)
```

## Cleanup

**Important**: Always destroy temporary hosts when finished to avoid unnecessary costs!

```bash
terraform destroy
```

## Files

- `main.tf` - Infrastructure configuration
- `variables.tf` - Input variables and validation
- `outputs.tf` - Output values and commands
- `versions.tf` - Provider requirements
- `terraform.tfvars.example` - Configuration template
- `.gitignore` - Git ignore rules

## Cost Estimates

- **ccx13** (2 vCPU, 8GB): ~$0.012/hour (~$0.29/day)
- **ccx23** (4 vCPU, 16GB): ~$0.025/hour (~$0.59/day)
- **ccx33** (8 vCPU, 32GB): ~$0.049/hour (~$1.18/day)

## Troubleshooting

See the main [SKILL.md](../../SKILL.md) for detailed troubleshooting guide.
