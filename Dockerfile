FROM dunglas/frankenphp:1.11-php8.4

ARG USER=appuser
ARG WORDPRESS_VERSION=6.9
COPY entrypoint.sh /docker-entrypoint.sh
RUN \
	useradd ${USER}; \
	setcap -r /usr/local/bin/frankenphp; \
	# Give write access to /config/caddy and /data/caddy
	chown -R ${USER}:${USER} /config/caddy /data/caddy /app && \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    chmod 755 /docker-entrypoint.sh 

RUN install-php-extensions \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    zip \
    # See https://github.com/Imagick/imagick/issues/640#issuecomment-2077206945
    imagick/imagick@master \
    opcache
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends default-mysql-client; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
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
    } > "$PHP_INI_DIR/conf.d/opcache-recommended.ini" && \
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

RUN \
    TMPDIR=$(mktemp -d) && \
    curl -L https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz | \
    tar -xzf - -C /app/public --strip-components=1 && \
    rm -rf ${TMPDIR} && \
    curl -L -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod 755 /usr/local/bin/wp && \
    curl -L -o /app/public/wp-config-docker.php https://raw.githubusercontent.com/docker-library/wordpress/master/wp-config-docker.php && \
    chown -R ${USER}:${USER}  /app/public && \
    mkdir -p /app/public/wp-content && \
    chown -R ${USER}:${USER}  /app/public/wp-content

USER ${USER}
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]