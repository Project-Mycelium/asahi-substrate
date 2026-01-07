image_name := "asahi-atomic"
registry := "ghcr.io"
username := `git config user.name | tr '[:upper:]' '[:lower:]' | tr -d ' '`
tag := "latest"

# Build the image locally for ARM64
build:
    podman build \
        --platform linux/arm64 \
        --tag {{image_name}}:{{tag}} \
        .

# Verify the hardware drivers in the built image
verify:
    podman run --rm {{image_name}}:{{tag}} lsinitrd | grep nvme-apple
    podman run --rm {{image_name}}:{{tag}} rpm -q kernel-16k asahi-fwupdate asahi-audio

# Push the image to the registry (Requires 'podman login ghcr.io')
push:
    podman tag {{image_name}}:{{tag}} {{registry}}/{{username}}/{{image_name}}:{{tag}}
    podman push {{registry}}/{{username}}/{{image_name}}:{{tag}}
