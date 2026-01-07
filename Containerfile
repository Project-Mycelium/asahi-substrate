# STAGE 1: THE EXTRACTOR
FROM quay.io/fedora/fedora:41 as extractor
RUN dnf install -y 'dnf5-command(copr)' cpio
RUN dnf copr enable -y @asahi/kernel
WORKDIR /payload
# Download and explode the kernel
RUN dnf download --resolve kernel-16k
RUN for rpm in *.rpm; do rpm2cpio "$rpm" | cpio -idm; done

# STAGE 2: THE FINAL ASSEMBLY
FROM quay.io/fedora/fedora-bootc:43

# 2a. Inject Userspace Tools (Still using DNF for now for stability)
RUN dnf install -y 'dnf5-command(copr)' && \
    dnf copr enable -y @asahi/mesa && \
    dnf install -y --setopt=install_weak_deps=False \
    mesa-dri-drivers \
    asahi-fwupdate \
    asahi-bless \
    asahi-audio \
    alsa-ucm-asahi \
    asahi-scripts \
    m1n1 \
    dracut-asahi && \
    dnf clean all

# 2b. The Kernel Graft (DNF-LESS)
COPY --from=extractor /payload/lib/modules /usr/lib/modules
RUN find /usr/lib/modules -name "vmlinuz*" -exec cp {} /boot/ \;

# 2c. Userspace Graft (Bluefin)
COPY --from=ghcr.io/ublue-os/bluefin:stable /usr/share/ublue-os /usr/share/ublue-os
COPY --from=ghcr.io/ublue-os/bluefin:stable /etc/zsh /etc/zsh
COPY --from=ghcr.io/ublue-os/bluefin:stable /usr/share/gnome-shell/extensions /usr/share/gnome-shell/extensions

# 2d. Initramfs Generation (Critical for Boot)
# We must run depmod before dracut because we grafted the files manually
RUN KERNEL_VER=$(ls /usr/lib/modules | grep asahi | head -n 1) && \
    echo "Running depmod for $KERNEL_VER" && \
    depmod -a $KERNEL_VER && \
    echo "Generating Initramfs for $KERNEL_VER" && \
    dracut --force --kver $KERNEL_VER

# 2e. Local Fixes
COPY build_files/color-tint.sh /usr/bin/wavy-nightlight
RUN chmod +x /usr/bin/wavy-nightlight
COPY build_files/wavy-nightlight.service /usr/lib/systemd/user/
RUN mkdir -p /usr/lib/systemd/user/default.target.wants && \
    ln -sf /usr/lib/systemd/user/wavy-nightlight.service /usr/lib/systemd/user/default.target.wants/wavy-nightlight.service
