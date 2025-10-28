# Network Configuration

## Network Interfaces

Each server in the cluster has two network interfaces:

1. **Public Interface** (eth0)
   - Assigned a public IPv4 address
   - IPv6 /64 subnet
   - Direct internet connectivity
   - Protected by firewall rules

2. **Internal/Private Interface** (eth1)
   - Connected to private network (10.0.0.0/16)
   - Static IP assignment (10.0.1.10+)
   - No internet routing
   - Used for inter-node communication

## Firewall Rules

The cluster uses a strict firewall configuration that allows only:

### Inbound Rules (from Internet)
- **SSH (TCP 22)**: Remote access for administration
- **HTTPS (TCP 443)**: Secure web traffic
- **ZeroTier (UDP 9993)**: VPN mesh networking

### Inbound Rules (from Private Network)
- **All TCP**: Any TCP port from 10.0.0.0/16
- **All UDP**: Any UDP port from 10.0.0.0/16
- **ICMP**: Ping and other ICMP from 10.0.0.0/16

### Outbound Rules
- All outbound traffic is allowed by default

## Private Network Details

- **Network Range**: 10.0.0.0/16 (65,536 addresses)
- **Subnet**: 10.0.1.0/24 (254 usable addresses)
- **Node IPs**: Start at 10.0.1.10
  - Node 1: 10.0.1.10
  - Node 2: 10.0.1.11
  - Node 3: 10.0.1.12
  - etc.

## Network Zones

Different datacenters use different network zones for private networks:

- **us-west**: For Hillsboro (hil-dc1)
- **ap-southeast**: For Singapore (sin-dc1)
- **eu-central**: For Falkenstein (fsn1-dc14)

Private networks can only span servers within the same network zone.

## ZeroTier Integration

Port 9993/UDP is open to support ZeroTier One for creating secure mesh networks:

- Allows nodes to join ZeroTier networks
- Enables encrypted peer-to-peer connections
- Useful for testing SDN and overlay networks
- Can connect to other nodes outside Hetzner Cloud

## SSH Access

SSH access is configured to use:

- **Port**: 22 (standard)
- **Authentication**: Public key only (keys uploaded to Hetzner)
- **User**: root (default for Hetzner Cloud servers)
- **Keys**: Loaded from local ~/.ssh/ directory

Example SSH command:
```bash
ssh root@<public-ip>
```

For private network testing, SSH through a bastion or use ZeroTier.
