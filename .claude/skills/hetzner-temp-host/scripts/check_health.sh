#!/bin/bash
#
# Health check script for deployed service on temporary Hetzner host
# Can be run standalone or called from Terraform provisioners
#
# Usage:
#   ./check_health.sh [host_ip] [health_check_url]
#
# Examples:
#   ./check_health.sh 1.2.3.4
#   ./check_health.sh 1.2.3.4 http://localhost:8080/health
#
# If no arguments provided, will try to get IP from terraform output
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
HOST_IP="${1:-}"
HEALTH_CHECK_URL="${2:-}"

# Try to get host IP from terraform output if not provided
if [ -z "${HOST_IP}" ]; then
    if [ -f "terraform.tfstate" ]; then
        echo -e "${YELLOW}Getting host IP from Terraform state...${NC}"
        HOST_IP=$(terraform output -raw public_ip 2>/dev/null || echo "")
    fi
fi

if [ -z "${HOST_IP}" ]; then
    echo -e "${RED}Error: Host IP not provided and could not be determined from Terraform state${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 <host_ip> [health_check_url]"
    echo ""
    echo "Example:"
    echo "  $0 1.2.3.4"
    echo "  $0 1.2.3.4 http://localhost:8080/health"
    exit 1
fi

echo -e "${BLUE}=== Health Check for ${HOST_IP} ===${NC}"
echo ""

# Check SSH connectivity
echo -e "${YELLOW}Checking SSH connectivity...${NC}"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${HOST_IP} "echo 'SSH OK'" &>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    exit 1
fi

# Check Docker status
echo ""
echo -e "${YELLOW}Checking Docker status...${NC}"
if ssh -o StrictHostKeyChecking=no root@${HOST_IP} "systemctl is-active docker" &>/dev/null; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker is not running${NC}"
    exit 1
fi

# Check Docker Compose containers
echo ""
echo -e "${YELLOW}Checking Docker Compose containers...${NC}"
CONTAINER_OUTPUT=$(ssh -o StrictHostKeyChecking=no root@${HOST_IP} "cd /opt/app && docker compose ps --format json 2>/dev/null" || echo "")

if [ -z "${CONTAINER_OUTPUT}" ]; then
    echo -e "${RED}✗ Could not get container status${NC}"
    exit 1
fi

# Count running containers
TOTAL=$(echo "${CONTAINER_OUTPUT}" | jq -s 'length' 2>/dev/null || echo "0")
RUNNING=$(echo "${CONTAINER_OUTPUT}" | jq -s '[.[] | select(.State == "running")] | length' 2>/dev/null || echo "0")

if [ "${RUNNING}" -eq 0 ]; then
    echo -e "${RED}✗ No containers are running (0/${TOTAL})${NC}"
    echo ""
    echo "Container details:"
    ssh -o StrictHostKeyChecking=no root@${HOST_IP} "cd /opt/app && docker compose ps"
    exit 1
elif [ "${RUNNING}" -eq "${TOTAL}" ]; then
    echo -e "${GREEN}✓ All containers are running (${RUNNING}/${TOTAL})${NC}"
else
    echo -e "${YELLOW}⚠ Some containers are running (${RUNNING}/${TOTAL})${NC}"
fi

# Show container details
echo ""
echo "Container status:"
ssh -o StrictHostKeyChecking=no root@${HOST_IP} "cd /opt/app && docker compose ps" | grep -E "NAME|---" || true
ssh -o StrictHostKeyChecking=no root@${HOST_IP} "cd /opt/app && docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Status}}'" 2>/dev/null || \
    ssh -o StrictHostKeyChecking=no root@${HOST_IP} "cd /opt/app && docker compose ps"

# Check ZeroTier status
echo ""
echo -e "${YELLOW}Checking ZeroTier status...${NC}"
ZT_OUTPUT=$(ssh -o StrictHostKeyChecking=no root@${HOST_IP} "zerotier-cli listnetworks 2>/dev/null" || echo "")

if [ -z "${ZT_OUTPUT}" ]; then
    echo -e "${YELLOW}⚠ Could not get ZeroTier status${NC}"
else
    ZT_STATUS=$(echo "${ZT_OUTPUT}" | tail -n +2 | awk '{print $6}' | head -n 1)
    ZT_NETWORK=$(echo "${ZT_OUTPUT}" | tail -n +2 | awk '{print $3}' | head -n 1)

    if [ "${ZT_STATUS}" = "OK" ]; then
        echo -e "${GREEN}✓ ZeroTier connected to network ${ZT_NETWORK}${NC}"

        # Get ZeroTier IP if available
        ZT_IP=$(echo "${ZT_OUTPUT}" | tail -n +2 | awk '{print $9}' | head -n 1 | cut -d'/' -f1)
        if [ -n "${ZT_IP}" ] && [ "${ZT_IP}" != "-" ]; then
            echo "  ZeroTier IP: ${ZT_IP}"
        fi
    elif [ "${ZT_STATUS}" = "ACCESS_DENIED" ]; then
        echo -e "${YELLOW}⚠ ZeroTier connected but not authorized (network ${ZT_NETWORK})${NC}"
        echo "  Authorize at: https://my.zerotier.com"
    else
        echo -e "${YELLOW}⚠ ZeroTier status: ${ZT_STATUS} (network ${ZT_NETWORK})${NC}"
    fi
fi

# Check HTTP endpoint if provided
if [ -n "${HEALTH_CHECK_URL}" ]; then
    echo ""
    echo -e "${YELLOW}Checking health endpoint: ${HEALTH_CHECK_URL}${NC}"

    HTTP_CODE=$(ssh -o StrictHostKeyChecking=no root@${HOST_IP} "curl -s -o /dev/null -w '%{http_code}' ${HEALTH_CHECK_URL}" 2>/dev/null || echo "000")

    if [ "${HTTP_CODE}" = "200" ]; then
        echo -e "${GREEN}✓ Health endpoint responding: HTTP ${HTTP_CODE}${NC}"
    elif [ "${HTTP_CODE}" = "000" ]; then
        echo -e "${RED}✗ Health endpoint not reachable${NC}"
    else
        echo -e "${YELLOW}⚠ Health endpoint returned: HTTP ${HTTP_CODE}${NC}"
    fi
fi

# System resources
echo ""
echo -e "${YELLOW}Checking system resources...${NC}"
ssh -o StrictHostKeyChecking=no root@${HOST_IP} "echo 'CPU Usage:'; top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print \"  Idle: \" \$1\"%\"}'; echo 'Memory:'; free -h | grep Mem | awk '{print \"  Total: \"\$2\"  Used: \"\$3\"  Free: \"\$4}'; echo 'Disk:'; df -h / | tail -n 1 | awk '{print \"  Total: \"\$2\"  Used: \"\$3\"  Available: \"\$4\"  Use%: \"\$5}'"

echo ""
echo -e "${GREEN}=== Health Check Complete ===${NC}"
echo ""

# Summary
if [ "${RUNNING}" -eq "${TOTAL}" ] && [ "${RUNNING}" -gt 0 ]; then
    echo -e "${GREEN}Status: Healthy${NC}"
    echo "  All containers running: ${RUNNING}/${TOTAL}"
    exit 0
elif [ "${RUNNING}" -gt 0 ]; then
    echo -e "${YELLOW}Status: Degraded${NC}"
    echo "  Containers running: ${RUNNING}/${TOTAL}"
    exit 1
else
    echo -e "${RED}Status: Unhealthy${NC}"
    echo "  No containers running"
    exit 1
fi
