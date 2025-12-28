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
    opcache && \
    echo 'opcache.enable=1' > "${PHP_INI_DIR}/conf.d/opcache-base.ini" && \
    echo 'opcache.enable_cli=1' >> "${PHP_INI_DIR}/conf.d/opcache-base.ini"

RUN \
    TMPDIR=$(mktemp -d) && \
    curl -L -o ${TMPDIR}/wordpress.tar.gz https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz && \
    tar -xzf ${TMPDIR}/wordpress.tar.gz -C ${TMPDIR} && \
    mv ${TMPDIR}/wordpress/* /app/public && \
    rm -rf ${TMPDIR} && \
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp 

USER ${USER}
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]