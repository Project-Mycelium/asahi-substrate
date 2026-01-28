#!/bin/bash
# Phase 3: Build and Push Containerfile
# Validates Phase 2 changes and pushes to registry

set -e

PROJECT_ROOT="/Users/eric/dev/personal/asahi-substrate"
REGISTRY="ghcr.io/ericrowan"
IMAGE_NAME="asahi-substrate"
TAG="${1:-latest}"

echo "=========================================="
echo "Phase 3: Build Asahi Substrate Container"
echo "=========================================="
echo "Registry: $REGISTRY"
echo "Image: $IMAGE_NAME"
echo "Tag: $TAG"
echo "Root: $PROJECT_ROOT"
echo ""

# Change to project directory
cd "$PROJECT_ROOT"

# Build the container image
echo "Step 1: Building container image..."
echo "Command: podman build -f src/Containerfile.substrate -t $REGISTRY/$IMAGE_NAME:$TAG ."
podman build -f src/Containerfile.substrate -t "$REGISTRY/$IMAGE_NAME:$TAG" .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "Image: $REGISTRY/$IMAGE_NAME:$TAG"
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi

# Show image info
echo ""
echo "Step 2: Image information"
podman images "$REGISTRY/$IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.Created}}"

echo ""
echo "Step 3: Push to registry? (optional)"
echo "Run: podman push $REGISTRY/$IMAGE_NAME:$TAG"
echo ""
echo "For hardware deployment, update deployment script with the tag."
echo "========================================"
