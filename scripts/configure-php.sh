#!/bin/sh
# ════════════════════════════════════════════════════════════════
# PHP Runtime Configuration Script
# ════════════════════════════════════════════════════════════════
#
# This script configures PHP settings based on php-settings.conf
# Run during Docker build to apply optimizations.
#

set -e

# Load configuration
# When running in Docker build, config is at /tmp/values-php
# Otherwise, load from root directory relative to script location
if [ -f "/tmp/values-php" ]; then
    CONFIG_FILE="/tmp/values-php"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT_DIR="$(dirname "$SCRIPT_DIR")"
    CONFIG_FILE="${ROOT_DIR}/values-php"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: values-php not found at $CONFIG_FILE"
    exit 1
fi

# Source configuration (extract key=value pairs, ignore comments)
eval "$(grep -E '^[A-Z_]+=' "$CONFIG_FILE")"

echo "🔧 Configuring PHP runtime..."

# ============================================================================
# Memory Configuration
# ============================================================================

cat > /usr/local/etc/php/conf.d/memory-limit.ini <<EOF
memory_limit=${PHP_MEMORY_LIMIT}
EOF

cat > /usr/local/etc/php/conf.d/upload-limit.ini <<EOF
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}
post_max_size=${PHP_POST_MAX_SIZE}
EOF

cat > /usr/local/etc/php/conf.d/execution-time.ini <<EOF
max_execution_time=${PHP_MAX_EXECUTION_TIME}
EOF

echo "✅ Memory limits configured"

# ============================================================================
# Performance Configuration
# ============================================================================

# Note: Realpath cache, JIT, and other advanced settings removed
# They can cause issues during Docker build (composer operations)
# Add them later in your app's production configuration if needed

echo "✅ Performance settings configured"

# ============================================================================
# OPcache with JIT Configuration
# ============================================================================

cat > /usr/local/etc/php/conf.d/opcache.ini <<EOF
opcache.enable=1
opcache.memory_consumption=${OPCACHE_MEMORY_CONSUMPTION}
opcache.interned_strings_buffer=${OPCACHE_INTERNED_STRINGS_BUFFER}
opcache.max_accelerated_files=${OPCACHE_MAX_ACCELERATED_FILES}
opcache.revalidate_freq=0
opcache.validate_timestamps=0
EOF

echo "✅ OPcache with JIT configured"

# ============================================================================
# Display Configuration Summary
# ============================================================================

echo ""
echo "📊 Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Memory:"
echo "  PHP Memory Limit:      ${PHP_MEMORY_LIMIT}"
echo "  Upload/POST Max Size:  ${PHP_UPLOAD_MAX_FILESIZE} / ${PHP_POST_MAX_SIZE}"
echo ""
echo "OPcache (shared memory):"
echo "  Memory Consumption:    ${OPCACHE_MEMORY_CONSUMPTION}M"
echo "  Interned Strings:      ${OPCACHE_INTERNED_STRINGS_BUFFER}M"
echo "  Max Files:             ${OPCACHE_MAX_ACCELERATED_FILES}"
echo ""
echo "JIT Compiler:"
echo "  Buffer Size:           ${JIT_BUFFER_SIZE}"
echo "  Mode:                  ${JIT_MODE}"
echo ""
echo "Realpath Cache:"
echo "  Size:                  ${REALPATH_CACHE_SIZE}"
echo "  TTL:                   ${REALPATH_CACHE_TTL}s"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ PHP configuration complete!"