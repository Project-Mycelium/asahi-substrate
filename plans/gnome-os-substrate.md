# GNOME OS Substrate Implementation Plan

**Date:** 2026-01-27
**Status:** NOT RECOMMENDED
**Conclusion:** Continue with Fedora Asahi bootc

## Summary

After thorough research, implementing a GNOME OS-based substrate for Apple Silicon is **not recommended**. This document explains why and provides alternative approaches if GNOME desktop functionality is desired.

## Why Not GNOME OS?

### Blocking Issues

1. **No Apple Silicon Support**
   - GNOME OS has no Asahi kernel integration
   - Missing Apple GPU drivers (Mesa Asahi)
   - No speaker protection daemon (hardware safety risk)
   - Cannot boot on M1/M2/M3 hardware

2. **Different Build Philosophy**
   - Uses BuildStream (complex, niche tooling)
   - Not compatible with bootc/Containerfile workflow
   - Would require complete architecture redesign

3. **Development-Only Distribution**
   - Explicitly not for production use
   - Nightly/unstable releases only
   - No stability guarantees

### Effort Estimate (If Attempted)

| Task | Estimated Time |
|------|----------------|
| Learn BuildStream | 2-4 weeks |
| Integrate Asahi kernel | 4-8 weeks |
| Port Mesa Asahi patches | 2-4 weeks |
| Audio/firmware integration | 2-4 weeks |
| Testing and stabilization | 4-8 weeks |
| **Total** | **14-28 weeks** |

Risk: No community support, may never achieve parity with Fedora Asahi.

## Recommended Alternative: GNOME on Fedora Asahi bootc

If GNOME desktop is needed, add it to the existing substrate via Containerfile.

### Option A: Minimal GNOME (Recommended)

Add to `src/Containerfile.substrate`:

```dockerfile
# -----------------------------------------------------------------------------
# OPTIONAL: GNOME Desktop Environment
# -----------------------------------------------------------------------------
# Only include if desktop GUI is required

RUN dnf install -y --setopt=install_weak_deps=False \
    gnome-shell \
    gnome-session \
    gnome-terminal \
    gnome-settings-daemon \
    gdm \
    && dnf clean all

# Auto-login for formless user (optional)
RUN mkdir -p /etc/gdm && \
    echo "[daemon]" > /etc/gdm/custom.conf && \
    echo "AutomaticLoginEnable=True" >> /etc/gdm/custom.conf && \
    echo "AutomaticLogin=formless" >> /etc/gdm/custom.conf

RUN systemctl enable gdm.service
```

### Option B: Full GNOME Desktop

```dockerfile
RUN dnf group install -y gnome-desktop-environment && \
    dnf clean all

RUN systemctl enable gdm.service
```

### Option C: Headless with Remote Desktop (Current Approach)

Keep current headless design, add remote desktop capabilities:

```dockerfile
# GNOME Remote Desktop for occasional GUI access
RUN dnf install -y \
    gnome-remote-desktop \
    && dnf clean all
```

## Implementation Decision Tree

```
Do you need a GUI on the substrate?
    |
    +-- NO --> Keep current headless design (RECOMMENDED)
    |          - SSH/Tailscale for access
    |          - Containers for applications
    |          - X11/Wayland forwarding if needed
    |
    +-- YES --> Do you need local display?
                    |
                    +-- NO --> Add GNOME Remote Desktop
                    |          (Option C above)
                    |
                    +-- YES --> Add GNOME to Containerfile
                               (Option A or B above)
```

## Impact on Current Architecture

### If Adding GNOME

| Component | Change Required |
|-----------|-----------------|
| Containerfile | Add GNOME packages (~500MB) |
| Image Size | Increase from ~2GB to ~3GB |
| Boot Time | Increase by ~5-10 seconds |
| Memory Usage | Increase by ~500MB at idle |
| Services | Add GDM, GNOME session |

### If Staying Headless (Recommended)

No changes required. Current architecture is optimal for:
- Server/substrate workloads
- Container-first applications
- Remote development
- Low resource overhead

## Future Considerations

### Watch These Developments

1. **Fedora Atomic GNOME (Silverblue)**
   - Already works on Apple Silicon via Asahi
   - Could be used as alternative base image
   - More tested GNOME integration

2. **Asahi Fedora Desktop Spins**
   - Official Fedora Asahi may add GNOME spin
   - Would be maintained by Asahi team
   - Best option if official GNOME support is needed

3. **bootc + GNOME convergence**
   - Fedora is unifying bootc across all editions
   - May simplify adding desktop in future

## Conclusion

**Do not pursue GNOME OS as a base.**

Current approach (Fedora Asahi bootc) is correct. If GNOME desktop is required, add it as packages to the existing Containerfile rather than changing the entire architecture.

### Action Items

- [x] Research GNOME OS - Complete, not suitable
- [x] Document findings - This document
- [ ] If GNOME needed: Add packages to Containerfile
- [ ] If GNOME needed: Test on hardware
- [ ] If GNOME needed: Update documentation
