# ════════════════════════════════════════════════════════════════
# DigitalOcean Laravel Runtime - Production-Ready Base Image
# ════════════════════════════════════════════════════════════════
#
# Optimized base image for Laravel Octane applications with:
# - PHP 8.4 CLI (Alpine Linux)
# - OpenSwoole 25.2.0 - High-performance async runtime
# - Supervisord - Process control system
# - PostgreSQL support - Optimized for DO managed databases
#
# Usage:
#   FROM ghcr.io/mente-io/do-laravel-runtime:latest
#
# ════════════════════════════════════════════════════════════════

# ============================================================================
# Build Stage - Compile PHP extensions and OpenSwoole
# ============================================================================
FROM php:8.4-cli-alpine AS builder

# Build arguments
ARG SWOOLE_VERSION=25.2.0

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
FROM php:8.4-cli-alpine

# Labels
LABEL description="Production-ready PHP 8.4 + OpenSwoole runtime for Laravel Octane on DigitalOcean Apps"
LABEL org.opencontainers.image.source="https://github.com/mente-io/do-laravel-runtime"

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
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

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
