#!/bin/bash
set -e

# Wait for wp-content volume to be ready
if [ ! -d "/app/public/wp-content" ]; then
    echo "Waiting for wp-content volume..."
    while [ ! -d "/app/public/wp-content" ]; do sleep 0.1; done
fi

# Initialize WordPress if not already done
if [ ! -f "/app/public/wp-config.php" ]; then
    echo "Initializing WordPress..."
    
    # Generate wp-config.php from environment variables
    wp config create \
        --dbname="${WORDPRESS_DB_NAME:-wordpress}" \
        --dbuser="${WORDPRESS_DB_USER:-wordpress}" \
        --dbpass="${WORDPRESS_DB_PASSWORD:-wordpress}" \
        --dbhost="${WORDPRESS_DB_HOST:-db:3306}" \
        --allow-root
    
    # Install WordPress
    wp core install \
        --url="${WORDPRESS_URL:-http://localhost:8000}" \
        --title="${WORDPRESS_TITLE:-WordPress}" \
        --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD:-admin}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
        --allow-root
fi

# Start FrankenPHP
exec "$@"
