# Hetzner Cloud Specifications

## Server Types (Compute Optimized - CCX Line)

### CCX13
- **vCPUs**: 2 (dedicated)
- **RAM**: 8 GB
- **Storage**: 80 GB NVMe SSD
- **Network**: 20 TB traffic
- **Cost**: ~€8.21/month (~$8.90/month)
- **Use case**: Small testing clusters, development

### CCX23
- **vCPUs**: 4 (dedicated)
- **RAM**: 16 GB
- **Storage**: 160 GB NVMe SSD
- **Network**: 20 TB traffic
- **Cost**: ~€16.41/month (~$17.80/month)
- **Use case**: Medium workloads, testing with more resources

### CCX33
- **vCPUs**: 8 (dedicated)
- **RAM**: 32 GB
- **Storage**: 240 GB NVMe SSD
- **Network**: 20 TB traffic
- **Cost**: ~€32.82/month (~$35.60/month)
- **Use case**: Larger test clusters, performance testing

## Datacenter Locations

### Hillsboro, OR, USA (hil-dc1)
- **Location Code**: `hil-dc1`
- **Network Zone**: `us-west`
- **Region**: United States West Coast
- **Latency**: Best for US West Coast and Asia-Pacific testing

### Singapore (sin-dc1)
- **Location Code**: `sin-dc1`
- **Network Zone**: `ap-southeast`
- **Region**: Asia-Pacific
- **Latency**: Best for Asia-Pacific testing

### Falkenstein, Germany (fsn1-dc14)
- **Location Code**: `fsn1-dc14`
- **Network Zone**: `eu-central`
- **Region**: Europe Central
- **Latency**: Best for European testing

## Network Specifications

- **Private Networks**: 10.0.0.0/16 range (customizable)
- **Public IPv4**: Included with each server
- **Public IPv6**: /64 subnet included
- **Bandwidth**: Up to 20 Gbps depending on server type
- **Traffic**: 20 TB included per server

## Operating System Images

- **Ubuntu 24.04 LTS** (Noble Numbat) - Default and recommended
- **Ubuntu 22.04 LTS** (Jammy Jellyfish) - Also supported
- Other distributions available but Ubuntu LTS recommended for stability
