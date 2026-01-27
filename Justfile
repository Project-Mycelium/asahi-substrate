image_name := "asahi-substrate"
registry := "ghcr.io"
username := `git config user.name | tr '[:upper:]' '[:lower:]' | tr -d ' '`
tag := "latest"

# Base images
fedora_base := "quay.io/fedora/fedora-bootc:43"
gnomeos_base := "quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly"

# Build the v2 hybrid image (GNOME + Bluefin graft)
build:
    podman build \
        --platform linux/arm64 \
        -f src/Containerfile \
        --tag {{image_name}}:{{tag}} \
        .

# Build the v3 minimal substrate (fedora-bootc base, ARM64)
build-substrate:
    podman build \
        --platform linux/arm64 \
        --build-arg BASE_IMAGE={{fedora_base}} \
        -f src/Containerfile.substrate \
        --tag {{image_name}}-minimal:{{tag}} \
        .

# Build substrate with GNOME OS base (BLOCKED - waiting for ARM64 support)
# GNOME OS nightly currently only publishes x86_64 images
# Track: https://gitlab.gnome.org/GNOME/gnome-build-meta/-/pipelines (look for aarch64 bootc)
build-substrate-gnomeos:
    @echo "ERROR: GNOME OS nightly does not have ARM64 bootc images yet"
    @echo "This target is a placeholder for when ARM64 support is added"
    @echo "For now, use 'just build-substrate' (fedora-bootc base)"
    @exit 1

# Build both variants
build-all: build build-substrate

# Verify the hardware drivers in the built image
verify:
    podman run --rm {{image_name}}:{{tag}} lsinitrd | grep nvme-apple
    podman run --rm {{image_name}}:{{tag}} rpm -q kernel-16k asahi-fwupdate asahi-audio

# Simulation: Install to a loopback file to verify bootloader config generation
test-install:
    @echo "🧪 Running Mock Installation..."
    podman run --rm --privileged --pid=host --security-opt label=type:unconfined_t \
        -v /var/tmp:/var/tmp \
        {{image_name}}:{{tag}} \
        /bin/bash -c \
        "truncate -s 5G /var/tmp/test.img && \
         mkfs.btrfs -f /var/tmp/test.img && \
         mkdir -p /var/tmp/mnt && \
         mount /var/tmp/test.img /var/tmp/mnt && \
         bootc install to-filesystem --skip-finalize /var/tmp/mnt && \
         if [ -d /var/tmp/mnt/boot/loader/entries ]; then echo '✅ Bootloader Entries Created'; else echo '❌ Bootloader Missing'; exit 1; fi && \
         umount /var/tmp/mnt && rm /var/tmp/test.img"

# Run the user setup wizard
setup:
    /usr/bin/wavy-setup

# Aliases
wavy: setup
spore: setup

# Push the image to the registry (Requires 'podman login ghcr.io')
push:
    podman tag {{image_name}}:{{tag}} {{registry}}/{{username}}/{{image_name}}:{{tag}}
    podman push {{registry}}/{{username}}/{{image_name}}:{{tag}}
