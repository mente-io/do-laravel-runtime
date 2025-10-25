#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Build script for DigitalOcean Laravel Runtime
# ════════════════════════════════════════════════════════════════
#
# This script loads version variables from the 'versions' file
# and builds the Docker image with the correct build arguments.
#
# Usage:
#   ./build.sh [options]
#
# Options:
#   --tag <tag>         Additional tag (can be used multiple times)
#   --label <label>     Additional label (can be used multiple times)
#   --push              Push the image after building
#   --platform <plat>   Target platform (default: linux/amd64)
#   --cache-from <src>  Cache source
#   --cache-to <dst>    Cache destination
#
# Examples:
#   ./build.sh                                    # Simple local build
#   ./build.sh --tag my-runtime                   # Local build with custom tag
#   ./build.sh --tag latest --tag v1.0.0 --push   # Multi-tag with push
#
# ════════════════════════════════════════════════════════════════

set -e

# Load versions from versions file
if [ ! -f "versions" ]; then
    echo "Error: versions file not found"
    exit 1
fi

# Source the versions file
set -a
source versions
set +a

# Initialize arrays for tags and labels
TAGS=()
LABELS=()
PUSH=""
PLATFORM="linux/amd64"
CACHE_FROM=""
CACHE_TO=""
BUILD_DATE="${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
VCS_REF="${VCS_REF:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            TAGS+=("$2")
            shift 2
            ;;
        --label)
            LABELS+=("$2")
            shift 2
            ;;
        --push)
            PUSH="--push"
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --cache-from)
            CACHE_FROM="--cache-from $2"
            shift 2
            ;;
        --cache-to)
            CACHE_TO="--cache-to $2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# If no tags specified, use default
if [ ${#TAGS[@]} -eq 0 ]; then
    TAGS=("do-laravel-runtime")
fi

# Build tag arguments
TAG_ARGS=()
for tag in "${TAGS[@]}"; do
    TAG_ARGS+=(--tag "$tag")
done

# Build label arguments
LABEL_ARGS=()
for label in "${LABELS[@]}"; do
    LABEL_ARGS+=(--label "$label")
done

echo "Building Docker image with:"
echo "  PHP_VERSION: $PHP_VERSION"
echo "  SWOOLE_VERSION: $SWOOLE_VERSION"
echo "  COMPOSER_VERSION: $COMPOSER_VERSION"
echo "  CLOUDFLARED_VERSION: $CLOUDFLARED_VERSION"
echo "  PLATFORM: $PLATFORM"
echo "  TAGS: ${TAGS[*]}"
echo ""

# Build the image
docker buildx build \
    --build-arg PHP_VERSION="$PHP_VERSION" \
    --build-arg SWOOLE_VERSION="$SWOOLE_VERSION" \
    --build-arg COMPOSER_VERSION="$COMPOSER_VERSION" \
    --build-arg CLOUDFLARED_VERSION="$CLOUDFLARED_VERSION" \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VCS_REF="$VCS_REF" \
    --platform "$PLATFORM" \
    $CACHE_FROM \
    $CACHE_TO \
    "${TAG_ARGS[@]}" \
    "${LABEL_ARGS[@]}" \
    $PUSH \
    .

echo ""
echo "✓ Build complete!"
