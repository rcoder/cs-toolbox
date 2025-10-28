#!/usr/bin/env python3
"""
Find and read SSH public keys from the local system.

This script searches for common SSH public key files in ~/.ssh/ and
returns the first one found, prioritizing Ed25519 keys.
"""

import sys
from pathlib import Path


def find_ssh_public_key():
    """Find SSH public key in standard locations."""
    ssh_dir = Path.home() / ".ssh"

    if not ssh_dir.exists():
        return None, "SSH directory ~/.ssh does not exist"

    # Priority order: Ed25519 > RSA > ECDSA > DSA
    key_files = [
        "id_ed25519.pub",
        "id_rsa.pub",
        "id_ecdsa.pub",
        "id_dsa.pub",
    ]

    for key_file in key_files:
        key_path = ssh_dir / key_file
        if key_path.exists():
            try:
                with open(key_path, 'r') as f:
                    key_content = f.read().strip()
                    if key_content:
                        return key_content, key_path
            except Exception as e:
                continue

    return None, "No SSH public key found in ~/.ssh/"


def main():
    """Main entry point."""
    key_content, key_path_or_error = find_ssh_public_key()

    if key_content:
        print(f"# Found SSH key: {key_path_or_error}", file=sys.stderr)
        print(key_content)
        return 0
    else:
        print(f"Error: {key_path_or_error}", file=sys.stderr)
        print("\nTo generate a new SSH key, run:", file=sys.stderr)
        print("  ssh-keygen -t ed25519 -C 'your-email@example.com'", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
