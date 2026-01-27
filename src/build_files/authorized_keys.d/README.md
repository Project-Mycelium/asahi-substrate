# Authorized SSH Keys

Drop public keys in this directory (one file per key or machine).
They will be concatenated into `/etc/skel/.ssh/authorized_keys` during image build.

## Usage

1. Add your key:
   ```bash
   cp ~/.ssh/id_ed25519.pub src/build_files/authorized_keys.d/my-machine.pub
   ```

2. Build includes all keys automatically

## Why This Exists

SSH key authorization is the #1 pain point for remote substrate access.
This directory makes it portable:
- Keys are baked into the image
- Works regardless of which machine you're building from
- No manual setup on first boot
