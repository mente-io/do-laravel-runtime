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

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        zip \
        intl \
        mbstring \
        xml \
        curl \
        opcache \
        pcntl \
        bcmath \
        sockets

# Install OpenSwoole
RUN pecl install openswoole-${SWOOLE_VERSION} \
    && docker-php-ext-enable openswoole

# Install Redis extension
RUN pecl install redis \
    && docker-php-ext-enable redis

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

# Install only runtime dependencies
RUN apk add --no-cache \
    # Image libraries
    libpng \
    libjpeg-turbo \
    freetype \
    # Archive support
    libzip \
    # Database support
    postgresql-client \
    postgresql-libs \
    # Internationalization
    icu-libs \
    # String processing
    oniguruma \
    # XML processing
    libxml2 \
    # Network
    curl \
    # Process management
    supervisor \
    # Version control
    git \
    # Utilities
    unzip \
    wget \
    bash \
    ca-certificates

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Composer from official image
COPY --from=composer:${COMPOSER_VERSION} /usr/bin/composer /usr/bin/composer

# Install cloudflared (optional - only if version is specified)
RUN if [ -n "$CLOUDFLARED_VERSION" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
        chmod +x /usr/local/bin/cloudflared; \
    fi

# Configure PHP for production
RUN echo "memory_limit=512M" > /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "upload_max_filesize=50M" > /usr/local/etc/php/conf.d/upload-limit.ini \
    && echo "post_max_size=50M" >> /usr/local/etc/php/conf.d/upload-limit.ini \
    && echo "max_execution_time=60" > /usr/local/etc/php/conf.d/execution-time.ini

# Configure OPcache for production
RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=16" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini

# Create application directory
WORKDIR /var/www

# Create supervisor configuration directory
RUN mkdir -p /etc/supervisor/conf.d

# Expose common ports
EXPOSE 8000 5173

# Default command
CMD ["/bin/sh"]
