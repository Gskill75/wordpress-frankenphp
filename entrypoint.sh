#!/bin/bash
set -Eeuo pipefail

WORDPRESS_DIR="/app/public"
WP_CLI="/usr/local/bin/wp"

# Fonction pour vérifier si WordPress est installé
check_wordpress_installation() {
    echo >&2 "Vérification de l'installation WordPress..."
    
    # Vérifie si la base de données est accessible
    if ! $WP_CLI db check --path="$WORDPRESS_DIR" --allow-root 2>/dev/null; then
        echo >&2 "Base de données non accessible ou non configurée"
        return 1
    fi
    
    # Vérifie si WordPress est installé en base de données
    if ! $WP_CLI core is-installed --path="$WORDPRESS_DIR" --allow-root 2>/dev/null; then
        echo >&2 "WordPress n'est pas installé dans la base de données"
        return 1
    fi
    
    echo >&2 "WordPress est déjà installé ✓"
    return 0
}

# Fonction pour installer WordPress
install_wordpress() {
    echo >&2 "Installation de WordPress..."
    
    # Variables requises avec valeurs par défaut
    WP_TITLE="${WORDPRESS_TITLE:-Mon Site WordPress}"
    WP_ADMIN_USER="${WORDPRESS_ADMIN_USER:-admin}"
    WP_ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-$(openssl rand -base64 12)}"
    WP_ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
    WP_URL="${WORDPRESS_URL:-http://localhost}"
    WP_LOCALE="${WORDPRESS_LOCALE:-fr_FR}"
    
    # Installation WordPress via WP-CLI
    if $WP_CLI core install \
        --path="$WORDPRESS_DIR" \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --locale="$WP_LOCALE" \
        --skip-email \
        --allow-root 2>&1; then
        
        echo >&2 "✓ WordPress installé avec succès!"
        echo >&2 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo >&2 "URL: $WP_URL"
        echo >&2 "Admin: $WP_ADMIN_USER"
        echo >&2 "Password: $WP_ADMIN_PASSWORD"
        echo >&2 "Email: $WP_ADMIN_EMAIL"
        echo >&2 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Configuration supplémentaire
        configure_wordpress
        
        return 0
    else
        echo >&2 "✗ Erreur lors de l'installation de WordPress"
        return 1
    fi
}

# Fonction de configuration post-installation
configure_wordpress() {
    echo >&2 "Configuration de WordPress..."
    
    # Désactive les mises à jour automatiques si souhaité
    if [ "${WORDPRESS_AUTO_UPDATE:-true}" = "false" ]; then
        $WP_CLI config set AUTOMATIC_UPDATER_DISABLED true --raw --type=constant --path="$WORDPRESS_DIR" --allow-root
    fi
    
    # Configure le timezone si défini
    if [ -n "${WORDPRESS_TIMEZONE:-}" ]; then
        $WP_CLI option update timezone_string "$WORDPRESS_TIMEZONE" --path="$WORDPRESS_DIR" --allow-root
    fi
    
    # Active/désactive les permaliens
    if [ "${WORDPRESS_PERMALINK_STRUCTURE:-}" ]; then
        $WP_CLI rewrite structure "$WORDPRESS_PERMALINK_STRUCTURE" --path="$WORDPRESS_DIR" --allow-root
    fi
    
    # Vide le cache
    $WP_CLI cache flush --path="$WORDPRESS_DIR" --allow-root 2>/dev/null || true
    
    echo >&2 "✓ Configuration terminée"
}

# Script principal
main() {
    cd "$WORDPRESS_DIR"
    
    # Génération du wp-config.php si nécessaire
    wpEnvs=( "${!WORDPRESS_@}" )
    if [ ! -s wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
        echo >&2 "Génération de wp-config.php..."
        
        awk '
            /put your unique phrase here/ {
                cmd = "head -c1m /dev/urandom | sha1sum | cut -d '\'' -f1"
                cmd | getline str
                close(cmd)
                gsub("put your unique phrase here", str)
            }
            { print }
        ' wp-config-docker.php > wp-config.php
        
        chmod 644 wp-config.php
        echo >&2 "✓ wp-config.php créé"
    fi
    
    # Attente que la base de données soit prête
    if [ -n "${WORDPRESS_DB_HOST:-}" ]; then
        echo >&2 "Attente de la disponibilité de la base de données..."
        timeout=30
        while ! $WP_CLI db check --path="$WORDPRESS_DIR" --allow-root 2>/dev/null; do
            timeout=$((timeout - 1))
            if [ $timeout -le 0 ]; then
                echo >&2 "✗ Timeout: base de données non accessible"
                break
            fi
            sleep 1
        done
        
        if [ $timeout -gt 0 ]; then
            echo >&2 "✓ Base de données accessible"
            
            # Vérification et installation si nécessaire
            if ! check_wordpress_installation; then
                install_wordpress || echo >&2 "⚠ Installation WordPress échouée, démarrage en mode manuel"
            fi
        fi
    else
        echo >&2 "⚠ Variable WORDPRESS_DB_HOST non définie, installation automatique désactivée"
    fi
    
    # Démarrage de FrankenPHP
    exec "$@"
}

main