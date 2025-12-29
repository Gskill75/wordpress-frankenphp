#!/bin/bash
set -Eeuo pipefail

cd /app/public
wpEnvs=( "${!WORDPRESS_@}" )
if [ ! -s wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
    echo >&2 "Generating wp-config.php from ${wpEnvs[*]}..."
    
    awk '
        /put your unique phrase here/ {
            cmd = "head -c1m /dev/urandom | sha1sum | cut -d '\\' -f1"
            cmd | getline str
            close(cmd)
            gsub("put your unique phrase here", str)
        }
        { print }
    ' wp-config-docker.php > wp-config.php
    
    chmod 644 wp-config.php
    echo >&2 "wp-config.php ready!"
fi

# Start FrankenPHP
exec "$@"
