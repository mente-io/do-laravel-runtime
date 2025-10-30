# ════════════════════════════════════════════════════════════════
# DigitalOcean Laravel Runtime - Production-Ready Base Image
# ════════════════════════════════════════════════════════════════
#
# Optimized base image for Laravel Octane applications with:
# - PHP CLI (Alpine Linux) - Version set in 'versions' file
# - OpenSwoole - High-performance async runtime - Version set in 'versions' file
# - Composer - Dependency management - Version set in 'versions' file
# - Supervisord - Process control system
# - PostgreSQL support - Optimized for DO managed databases
# - Cloudflared (optional) - Version set in 'versions' file
#
# Usage:
#   FROM ghcr.io/mente-io/do-laravel-runtime:latest
#
# Build with custom versions:
#   docker build --build-arg PHP_VERSION=8.4-cli-alpine \
#                --build-arg SWOOLE_VERSION=25.2.0 \
#                --build-arg COMPOSER_VERSION=2 \
#                --build-arg CLOUDFLARED_VERSION=2024.12.2 \
#                -t my-runtime .
#
# ════════════════════════════════════════════════════════════════

# ============================================================================
# Build Stage - Compile PHP extensions and OpenSwoole
# ============================================================================

# Build arguments (set in versions file)
ARG PHP_VERSION
ARG SWOOLE_VERSION
ARG COMPOSER_VERSION
ARG CLOUDFLARED_VERSION

FROM php:${PHP_VERSION} AS builder

# Re-declare build arguments for this stage
ARG SWOOLE_VERSION

# Install build dependencies
RUN apk add --no-cache \
    autoconf \
    g++ \
    make \
    gcc \
    libc-dev \
    pkgconfig \
    linux-headers \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    postgresql-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    curl-dev

# Copy configuration and installation scripts
COPY values-php /tmp/values-php
COPY scripts/install-php-extensions.sh /tmp/install-php-extensions.sh

# Install PHP extensions using script
RUN chmod +x /tmp/install-php-extensions.sh && \
    /tmp/install-php-extensions.sh

# ============================================================================
# Composer Stage - Extract composer binary
# ============================================================================

ARG COMPOSER_VERSION
FROM composer:${COMPOSER_VERSION} AS composer

# ============================================================================
# Final Stage - Minimal runtime image
# ============================================================================

# Re-declare build arguments for final stage
ARG PHP_VERSION
ARG SWOOLE_VERSION
ARG COMPOSER_VERSION
ARG CLOUDFLARED_VERSION

FROM php:${PHP_VERSION}

# Labels with dynamic versions
LABEL description="Production-ready PHP ${PHP_VERSION} + OpenSwoole ${SWOOLE_VERSION} runtime for Laravel Octane on DigitalOcean Apps"
LABEL org.opencontainers.image.source="https://github.com/mente-io/do-laravel-runtime"
LABEL php.version="${PHP_VERSION}"
LABEL swoole.version="${SWOOLE_VERSION}"
LABEL composer.version="${COMPOSER_VERSION}"
LABEL cloudflared.version="${CLOUDFLARED_VERSION}"

# Install only runtime dependencies (ultra-minimal set for production)
RUN apk add --no-cache \
    # Image libraries (only if you use image processing) \
    libpng \
    libjpeg-turbo \
    freetype \
    # Archive support \
    libzip \
    # Database support \
    postgresql-client \
    postgresql-libs \
    # Internationalization \
    icu-libs \
    # String processing \
    oniguruma \
    # XML processing \
    libxml2 \
    # Network \
    curl \
    # Process management - using edge repo for latest version (4.3.0+) without pkg_resources warnings \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main supervisor \
    # Utilities (absolute minimum) \
    ca-certificates \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && rm -rf /usr/local/lib/php/doc \
    && rm -rf /usr/local/lib/php/test

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Composer from composer stage
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Install cloudflared (optional - only if version is specified)
RUN if [ -n "$CLOUDFLARED_VERSION" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
        chmod +x /usr/local/bin/cloudflared; \
    fi

# Copy configuration script and configure PHP
COPY values-php /tmp/values-php
COPY scripts/configure-php.sh /tmp/configure-php.sh
RUN chmod +x /tmp/configure-php.sh && \
    /tmp/configure-php.sh && \
    rm /tmp/values-php /tmp/configure-php.sh

# Create application directory
WORKDIR /var/www

# Create supervisor configuration directory
RUN mkdir -p /etc/supervisor/conf.d

# Expose common ports
EXPOSE 8000 5173

# Default command
CMD ["/bin/sh"]
