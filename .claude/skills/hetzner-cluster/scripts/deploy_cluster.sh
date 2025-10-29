#!/bin/bash
#
# Helper script to deploy a Hetzner cluster using Terraform
#
# Usage:
#   ./deploy_cluster.sh [cluster_name_prefix] [node_count] [server_type] [datacenter]
#
# Note: A random pet name will be automatically generated and appended to the cluster name.
#       For example, "myapp" becomes "myapp-happy-turtle"
#       Leave cluster_name_prefix empty for just the random name (e.g., "happy-turtle")
#
# Examples:
#   ./deploy_cluster.sh "" 3 ccx13 hillsboro           # Random name only
#   ./deploy_cluster.sh myapp 3 ccx13 hillsboro        # myapp-happy-turtle
#   ./deploy_cluster.sh test 2 ccx23 singapore         # test-clever-penguin
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${1:-}"
NODE_COUNT="${2:-3}"
SERVER_TYPE="${3:-ccx13}"
DATACENTER="${4:-hillsboro}"

echo -e "${BLUE}=== Hetzner Cluster Deployment ===${NC}"
echo ""
echo "Configuration:"
if [ -z "${CLUSTER_NAME}" ]; then
    echo "  Cluster Name: (random pet name will be generated)"
else
    echo "  Cluster Name: ${CLUSTER_NAME}-(random pet name)"
fi
echo "  Node Count:   ${NODE_COUNT}"
echo "  Server Type:  ${SERVER_TYPE}"
echo "  Datacenter:   ${DATACENTER}"
echo ""

# Check if Hetzner API token is set
if [ -z "${HCLOUD_TOKEN}" ]; then
    echo -e "${RED}Error: HCLOUD_TOKEN environment variable is not set${NC}"
    echo "Please set your Hetzner Cloud API token:"
    echo "  export HCLOUD_TOKEN='your-token-here'"
    exit 1
fi

# Check if ZeroTier API token is set
if [ -z "${ZEROTIER_API_TOKEN}" ]; then
    echo -e "${RED}Error: ZEROTIER_API_TOKEN environment variable is not set${NC}"
    echo "Please set your ZeroTier Central API token:"
    echo "  export ZEROTIER_API_TOKEN='your-token-here'"
    echo "Get your token from: https://my.zerotier.com/account"
    exit 1
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
zerotier_api_token   = "${ZEROTIER_API_TOKEN}"
cluster_name         = "${CLUSTER_NAME}"
node_count           = ${NODE_COUNT}
server_type          = "${SERVER_TYPE}"
datacenter           = "${DATACENTER}"
ssh_private_key_path = "${SSH_KEY_PATH}"
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
terraform apply -auto-approve

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform apply failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "To view cluster information:"
echo "  terraform output"
echo ""
echo "To SSH into nodes:"
echo "  terraform output -json ssh_commands | jq -r '.[]'"
echo ""
echo "ZeroTier network information:"
echo "  terraform output zerotier_network_id"
echo "  terraform output zerotier_member_ips"
echo ""
echo "To join this network from another device:"
echo "  terraform output -raw zerotier_join_command"
echo ""
echo "To destroy the cluster:"
echo "  terraform destroy"
