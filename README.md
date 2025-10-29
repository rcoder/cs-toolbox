# CS Toolbox

A collection of Claude Code skills, scripts, and examples for customer demos, troubleshooting, and testing.

## Custom Skills

### hetzner-cluster
Toolkit for creating and managing server clusters on Hetzner Cloud using Terraform. Provides pre-configured templates with:
- Automatic ZeroTier network creation and provisioning
- Secure networking (public + private interfaces, strict firewalls)
- Support for multiple datacenters (Hillsboro, Singapore, Germany)
- Easy cluster deployment and management

**Usage:** Invoke with `/skill hetzner-cluster` in a Claude Code session.

## Getting Started

1. **Set up environment variables:**
   ```bash
   cp envrc.example .envrc
   # Edit .envrc with your API tokens
   direnv allow
   ```

2. **Load skills in Claude Code:**
   - Skills in `.claude/skills/` are automatically available
   - Use `/skill <skill-name>` to invoke a skill
   - Example: `/skill hetzner-cluster`

3. **Development environment:**
   ```bash
   nix develop  # Enter development shell with all tools
   ```

## Repository Structure

```
.
├── .claude/skills/       # Custom Claude Code skills
│   └── hetzner-cluster/  # Hetzner Cloud cluster management
├── clusters/             # Cluster deployment configurations
│   └── demo-cluster/     # Example cluster deployment
└── envrc.example         # Environment variable template
```

## Requirements

- [direnv](https://direnv.net/) for environment management
- [Nix](https://nixos.org/) for development environment (optional)
- Claude Code CLI

## Contributing

This is a toolbox for customer success work. Add new skills, scripts, and examples as needed for demos and testing.
