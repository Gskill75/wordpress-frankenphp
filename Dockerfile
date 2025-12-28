FROM dunglas/frankenphp:1.11-php8.4

ARG USER=appuser
ARG WORDPRESS_VERSION=6.9
RUN \
	useradd ${USER}; \
	setcap -r /usr/local/bin/frankenphp; \
	# Give write access to /config/caddy and /data/caddy
	chown -R ${USER}:${USER} /config/caddy /data/caddy /app
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

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

RUN \
    TMPDIR=$(mktemp -d) && \
    wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz -O ${TMPDIR}/wordpress.tar.gz && \
    tar -xzf ${TMPDIR}/wordpress.tar.gz -C ${TMPDIR} && \
    mv ${TMPDIR}/wordpress/* /app/public && \
    rm -rf ${TMPDIR} && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

USER ${USER}
