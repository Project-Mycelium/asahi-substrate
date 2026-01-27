# Decision Log

## 2026-01-05: Architectural Transition to Verifiable Bootc Image

**Context:**
Transitioning from legacy BlueBuild workflows to a pure container-native (bootc) approach for Wavy-OS on Apple Silicon.

**Decision:**
Implemented a build-time hardware validation step using `lsinitrd` within the `Justfile`.

**Impact:**
- Ensures the initramfs contains critical Apple Silicon drivers (NVMe, AIC, Mailbox) before deployment.
- Prevents unbootable images from being pushed to the registry.
- Standardizes the build loop around `just build-wavy`.
