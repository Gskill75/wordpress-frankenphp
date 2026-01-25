FROM dunglas/frankenphp:1.11-php8.4

ARG WORDPRESS_VERSION=6.9
ARG UID=1000
ARG GID=0

# Install PHP extensions (requires root)
RUN install-php-extensions \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    zip \
    imagick/imagick@master \
    opcache

# Install MySQL client for health checks
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends default-mysql-client; \
    rm -rf /var/lib/apt/lists/*

# Configure PHP for production
RUN set -eux; \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    { \
        echo 'opcache.enable=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.validate_timestamps=1'; \
        echo 'opcache.save_comments=1'; \
        echo 'opcache.fast_shutdown=1'; \
    } > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"; \
    { \
        echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
        echo 'log_errors_max_len = 1024'; \
        echo 'ignore_repeated_errors = On'; \
        echo 'ignore_repeated_source = Off'; \
        echo 'html_errors = Off'; \
    } > "$PHP_INI_DIR/conf.d/error-logging.ini"

# Download WordPress and WP-CLI
RUN set -eux; \
    curl -fsSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" | \
        tar -xzf - -C /app/public --strip-components=1; \
    curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
    chmod 755 /usr/local/bin/wp; \
    curl -fsSL -o /app/public/wp-config-docker.php https://raw.githubusercontent.com/docker-library/wordpress/master/wp-config-docker.php

# Create non-root user with fixed UID
# GID=0 (root group) for OpenShift arbitrary UID compatibility
RUN set -eux; \
    useradd -u ${UID} -g ${GID} -d /app -s /bin/bash appuser; \
    # Remove capabilities from frankenphp for rootless operation
    setcap -r /usr/local/bin/frankenphp; \
    # Create necessary directories
    mkdir -p /app/public/wp-content /app/.wp-cli/cache; \
    # Set ownership and group permissions for rootless + arbitrary UID support
    chown -R ${UID}:${GID} /app /config/caddy /data/caddy; \
    # Group write permissions for OpenShift (arbitrary UID in root group)
    chmod -R g=u /app /config/caddy /data/caddy

# Copy entrypoint with proper permissions
COPY --chmod=755 entrypoint.sh /docker-entrypoint.sh

# Environment for WP-CLI and rootless operation
ENV HOME=/app
ENV WP_CLI_CACHE_DIR=/app/.wp-cli/cache

EXPOSE 8080

# Use numeric UID for K8s compatibility
USER ${UID}

WORKDIR /app/public

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
