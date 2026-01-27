image_name := "asahi-substrate"
registry := "ghcr.io"
username := `git config user.name | tr '[:upper:]' '[:lower:]' | tr -d ' '`
tag := "latest"

# Build the image locally for ARM64
build:
    podman build \
        --platform linux/arm64 \
        -f source/Containerfile \
        --tag {{image_name}}:{{tag}} \
        .

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
