# asahi-substrate

A **Hybrid Substrate** for Apple Silicon (Fedora Bootc + Asahi Kernel Graft).

## 🏗️ Architecture V2
*   **Kernel Strategy:** "Graft" (DNF-Less). The kernel is extracted from RPMs in a sterile stage and copied directly to the final image.
*   **Base:** `quay.io/fedora/fedora-bootc:43`
*   **Userspace:** "Inoculated" with Bluefin CLI tools, ZSH configs, and GNOME enhancements.

## 🚀 Deployment
**Prerequisites:**
*   Podman & Just
*   Target: M1/M2 Apple Silicon (M3/M4 Experimental)

**Build & Push:**
```bash
just build   # Builds linux/arm64 locally
just verify  # Checks initramfs for NVMe drivers
just push    # Pushes to your GHCR
```
