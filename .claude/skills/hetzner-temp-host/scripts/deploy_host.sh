#!/bin/bash
#
# Helper script to deploy a service from GitHub to a temporary Hetzner host
#
# Usage:
#   ./deploy_host.sh <github_repo_url> [host_name] [server_type] [datacenter] [branch]
#
# Examples:
#   ./deploy_host.sh https://github.com/user/myapp
#   ./deploy_host.sh https://github.com/user/myapp my-test-host
#   ./deploy_host.sh https://github.com/user/myapp my-api ccx23 singapore
#   ./deploy_host.sh https://github.com/user/myapp my-api ccx13 hillsboro feature-branch
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
GITHUB_REPO_URL="${1:-}"
HOST_NAME="${2:-}"
SERVER_TYPE="${3:-ccx13}"
DATACENTER="${4:-hillsboro}"
GITHUB_BRANCH="${5:-main}"

# Validate required arguments
if [ -z "${GITHUB_REPO_URL}" ]; then
    echo -e "${RED}Error: GitHub repository URL is required${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 <github_repo_url> [host_name] [server_type] [datacenter] [branch]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/myapp"
    echo "  $0 https://github.com/user/myapp my-test-host"
    echo "  $0 https://github.com/user/myapp my-api ccx23 singapore"
    echo "  $0 https://github.com/user/myapp my-api ccx13 hillsboro feature-branch"
    exit 1
fi

echo -e "${BLUE}=== Hetzner Temporary Host Deployment ===${NC}"
echo ""
echo "Configuration:"
echo "  Repository:   ${GITHUB_REPO_URL}"
echo "  Branch:       ${GITHUB_BRANCH}"
if [ -z "${HOST_NAME}" ]; then
    echo "  Host Name:    (random name will be generated)"
else
    echo "  Host Name:    ${HOST_NAME}"
fi
echo "  Server Type:  ${SERVER_TYPE}"
echo "  Datacenter:   ${DATACENTER}"
echo ""

# Check if Hetzner API token is set
if [ -z "${HCLOUD_TOKEN}" ]; then
    echo -e "${RED}Error: HCLOUD_TOKEN environment variable is not set${NC}"
    echo "Please set your Hetzner Cloud API token:"
    echo "  export HCLOUD_TOKEN='your-token-here'"
    echo ""
    echo "Get your token from: https://console.hetzner.cloud/"
    exit 1
fi

# Check if ZeroTier network ID is set
if [ -z "${ZEROTIER_NETWORK_ID}" ]; then
    echo -e "${RED}Error: ZEROTIER_NETWORK_ID environment variable is not set${NC}"
    echo "Please set your ZeroTier network ID:"
    echo "  export ZEROTIER_NETWORK_ID='your-network-id'"
    echo ""
    echo "Get your network ID from: https://my.zerotier.com"
    exit 1
fi

# Validate ZeroTier network ID format (16 hex characters)
if ! [[ "${ZEROTIER_NETWORK_ID}" =~ ^[0-9a-f]{16}$ ]]; then
    echo -e "${RED}Error: Invalid ZeroTier network ID format${NC}"
    echo "Network ID must be a 16-character hexadecimal string"
    echo "Example: 1c33c1ced02a5a44"
    exit 1
fi

echo -e "${GREEN}✓ ZeroTier Network ID: ${ZEROTIER_NETWORK_ID}${NC}"

# ZeroTier API token is optional (only needed for auto-authorization)
if [ -z "${ZEROTIER_API_TOKEN}" ]; then
    echo -e "${YELLOW}Note: ZEROTIER_API_TOKEN not set (manual authorization may be required)${NC}"
fi

# Determine SSH key path
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo -e "${RED}Error: SSH private key not found at ${SSH_KEY_PATH}${NC}"
    echo "Please set SSH_KEY_PATH environment variable or ensure key exists at ~/.ssh/id_ed25519"
    exit 1
fi

if [ ! -f "${SSH_KEY_PATH}.pub" ]; then
    echo -e "${RED}Error: SSH public key not found at ${SSH_KEY_PATH}.pub${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found SSH key pair at ${SSH_KEY_PATH}${NC}"
echo ""

# Create terraform.tfvars
echo -e "${YELLOW}Creating terraform.tfvars...${NC}"
cat > terraform.tfvars <<EOF
hcloud_token         = "${HCLOUD_TOKEN}"
zerotier_api_token   = "${ZEROTIER_API_TOKEN:-}"
zerotier_network     = "${ZEROTIER_NETWORK_ID}"
github_repo_url      = "${GITHUB_REPO_URL}"
github_branch        = "${GITHUB_BRANCH}"
host_name            = "${HOST_NAME}"
server_type          = "${SERVER_TYPE}"
datacenter           = "${DATACENTER}"
ssh_private_key_path = "${SSH_KEY_PATH}"
health_check_enabled = true
EOF

echo -e "${GREEN}✓ Created terraform.tfvars${NC}"
echo ""

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform init failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Plan
echo -e "${YELLOW}Planning Terraform changes...${NC}"
terraform plan

echo ""
read -p "Do you want to apply these changes? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Apply
echo -e "${YELLOW}Applying Terraform configuration...${NC}"
echo -e "${YELLOW}This will:${NC}"
echo "  1. Provision a Hetzner Cloud server"
echo "  2. Install Docker, Docker Compose, and ZeroTier"
echo "  3. Join the ZeroTier network ${ZEROTIER_NETWORK_ID}"
echo "  4. Clone ${GITHUB_REPO_URL}"
echo "  5. Deploy with Docker Compose"
echo "  6. Run health checks"
echo ""

terraform apply -auto-approve

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform apply failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""

# Get outputs
HOST_IP=$(terraform output -raw public_ip 2>/dev/null || echo "unknown")
HOST_NAME_OUTPUT=$(terraform output -raw host_name 2>/dev/null || echo "unknown")

echo -e "${BLUE}Host Information:${NC}"
echo "  Name:       ${HOST_NAME_OUTPUT}"
echo "  Public IP:  ${HOST_IP}"
echo "  ZeroTier:   ${ZEROTIER_NETWORK_ID}"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo "  SSH:           terraform output -raw ssh_command"
echo "  Docker Status: terraform output -raw docker_status_command"
echo "  Docker Logs:   terraform output -raw docker_logs_command"
echo ""

echo -e "${BLUE}Service Access:${NC}"
echo "  Check ports:   ssh root@${HOST_IP} 'docker compose -f /opt/app/docker-compose.yml ps'"
echo "  View logs:     ssh root@${HOST_IP} 'docker compose -f /opt/app/docker-compose.yml logs -f'"
echo ""

echo -e "${BLUE}ZeroTier:${NC}"
echo "  Get Node ID:   ssh root@${HOST_IP} \"zerotier-cli info | cut -d' ' -f3\""
echo "  Check Status:  ssh root@${HOST_IP} 'zerotier-cli listnetworks'"

if [ -z "${ZEROTIER_API_TOKEN}" ]; then
    echo ""
    echo -e "${YELLOW}Important: Authorize this node at https://my.zerotier.com${NC}"
fi

echo ""
echo -e "${BLUE}Management:${NC}"
echo "  View outputs:  terraform output"
echo "  Destroy host:  terraform destroy"
echo ""

# Cost reminder
COST_HOURLY=$(terraform output -raw estimated_cost_hourly 2>/dev/null || echo "~\$0.012/hour")
COST_DAILY=$(terraform output -raw estimated_cost_daily 2>/dev/null || echo "~\$0.29/day")
echo -e "${YELLOW}Cost Reminder:${NC}"
echo "  Estimated: ${COST_HOURLY} (${COST_DAILY})"
echo -e "  ${RED}Don't forget to run 'terraform destroy' when done!${NC}"
echo ""
