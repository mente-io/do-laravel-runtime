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

FROM php:8.4-cli-alpine

# Build arguments
ARG SWOOLE_VERSION=25.2.0

# Labels
LABEL description="Production-ready PHP 8.4 + OpenSwoole runtime for Laravel Octane on DigitalOcean Apps"
LABEL org.opencontainers.image.source="https://github.com/mente-io/do-laravel-runtime"

# Install system dependencies
RUN apk add --no-cache \
    # Build dependencies
    autoconf \
    g++ \
    make \
    gcc \
    libc-dev \
    pkgconfig \
    linux-headers \
    # PHP extensions dependencies
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    postgresql-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    curl-dev \
    # Runtime dependencies
    supervisor \
    git \
    unzip \
    curl \
    wget \
    bash \
    ca-certificates \
    # PostgreSQL client
    postgresql-client

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

# Install Swoole (OpenSwoole)
RUN pecl install openswoole-${SWOOLE_VERSION} \
    && docker-php-ext-enable openswoole

# Install Redis extension
RUN pecl install redis \
    && docker-php-ext-enable redis

# Configure PHP
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

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create application directory
WORKDIR /var/www

# Create supervisor configuration directory
RUN mkdir -p /etc/supervisor/conf.d

# Cleanup
RUN apk del autoconf g++ make gcc libc-dev pkgconfig linux-headers \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# Expose common ports
EXPOSE 8000 5173

# Default command (can be overridden)
CMD ["/bin/sh"]
