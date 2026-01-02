#!/bin/bash
set -Eeuo pipefail

WORDPRESS_DIR="/app/public"
WP_CLI="/usr/local/bin/wp"

wp() {
  "$WP_CLI" --path="$WORDPRESS_DIR" --allow-root "$@"
}

check_wordpress_installation() {
  echo >&2 "Vérification de l'installation WordPress..."

  if ! wp db check >/dev/null 2>&1; then
    echo >&2 "Base de données non accessible ou non configurée"
    return 1
  fi

  if ! wp core is-installed >/dev/null 2>&1; then
    echo >&2 "WordPress n'est pas installé dans la base de données"
    return 1
  fi

  echo >&2 "WordPress est déjà installé ✓"
  return 0
}

configure_wordpress() {
  echo >&2 "Configuration de WordPress..."

  if [ "${WORDPRESS_AUTO_UPDATE:-true}" = "false" ]; then
    wp config set AUTOMATIC_UPDATER_DISABLED true --raw --type=constant >/dev/null 2>&1 || true
  fi

  if [ -n "${WORDPRESS_TIMEZONE:-}" ]; then
    wp option update timezone_string "$WORDPRESS_TIMEZONE" >/dev/null 2>&1 || true
  fi

  if [ -n "${WORDPRESS_PERMALINK_STRUCTURE:-}" ]; then
    wp rewrite structure "$WORDPRESS_PERMALINK_STRUCTURE" >/dev/null 2>&1 || true
  fi

  wp cache flush >/dev/null 2>&1 || true
  echo >&2 "✓ Configuration terminée"
}

install_wordpress() {
  echo >&2 "Installation de WordPress..."

  WP_TITLE="${WORDPRESS_TITLE:-Mon Site WordPress}"
  WP_ADMIN_USER="${WORDPRESS_ADMIN_USER:-admin}"
  WP_ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-$(openssl rand -base64 18)}"
  WP_ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
  WP_URL="${WORDPRESS_URL:-http://localhost}"
  WP_LOCALE="${WORDPRESS_LOCALE:-fr_FR}"

  if wp core install \
      --url="$WP_URL" \
      --title="$WP_TITLE" \
      --admin_user="$WP_ADMIN_USER" \
      --admin_password="$WP_ADMIN_PASSWORD" \
      --admin_email="$WP_ADMIN_EMAIL" \
      --locale="$WP_LOCALE" \
      --skip-email
  then
    echo >&2 "✓ WordPress installé avec succès!"
    echo >&2 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo >&2 "URL: $WP_URL"
    echo >&2 "Admin: $WP_ADMIN_USER"
    echo >&2 "Password: $WP_ADMIN_PASSWORD"
    echo >&2 "Email: $WP_ADMIN_EMAIL"
    echo >&2 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    configure_wordpress
    return 0
  else
    echo >&2 "✗ Erreur lors de l'installation de WordPress"
    return 1
  fi
}

generate_wp_config_if_needed() {
  # Détection fiable des variables WORDPRESS_ (au lieu de "${!WORDPRESS_@}")
  mapfile -t wpEnvs < <(compgen -A variable WORDPRESS_ || true)

  if [ ! -s "$WORDPRESS_DIR/wp-config.php" ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
    echo >&2 "Génération de wp-config.php..."

    if [ ! -f "$WORDPRESS_DIR/wp-config-docker.php" ]; then
      echo >&2 "✗ wp-config-docker.php introuvable dans $WORDPRESS_DIR"
      return 1
    fi

    cp "$WORDPRESS_DIR/wp-config-docker.php" "$WORDPRESS_DIR/wp-config.php"

    # Remplacer chaque occurrence de "put your unique phrase here" par une clé aléatoire (alphanum uniquement)
    while grep -q "put your unique phrase here" "$WORDPRESS_DIR/wp-config.php"; do
      RANDOM_KEY="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)"
      sed -i "0,/put your unique phrase here/s/put your unique phrase here/$RANDOM_KEY/" "$WORDPRESS_DIR/wp-config.php"
    done

    chmod 0644 "$WORDPRESS_DIR/wp-config.php"
    echo >&2 "✓ wp-config.php créé"
  fi

  # IMPORTANT: rendre la config DB déterministe (ne dépend plus du template getenv_docker)
  if [ -n "${WORDPRESS_DB_HOST:-}" ] && [ -n "${WORDPRESS_DB_NAME:-}" ] && [ -n "${WORDPRESS_DB_USER:-}" ] && [ -n "${WORDPRESS_DB_PASSWORD:-}" ]; then
    wp config set DB_HOST "${WORDPRESS_DB_HOST}" >/dev/null 2>&1 || true
    wp config set DB_NAME "${WORDPRESS_DB_NAME}" >/dev/null 2>&1 || true
    wp config set DB_USER "${WORDPRESS_DB_USER}" >/dev/null 2>&1 || true
    wp config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD}" >/dev/null 2>&1 || true
  fi
}

wait_for_db_wpcli() {
  echo >&2 "Attente de la disponibilité de la base de données (via WP-CLI)..."

  local initial_delay="${WORDPRESS_DB_INITIAL_DELAY:-5}"
  local timeout="${WORDPRESS_DB_WAIT_TIMEOUT:-180}"

  local elapsed=0
  local sleep_s=1
  local attempt=0

  if [ ! -s "$WORDPRESS_DIR/wp-config.php" ]; then
    echo >&2 "✗ wp-config.php absent; impossible de tester la DB via WP-CLI"
    return 1
  fi

  if [ "$initial_delay" -gt 0 ]; then
    echo >&2 "Délai initial avant tests DB: ${initial_delay}s"
    sleep "$initial_delay"
    elapsed=$((elapsed + initial_delay))
  fi

  while true; do
    attempt=$((attempt + 1))

    # Log de tentative (avec temps écoulé)
    echo >&2 "DB check (tentative #${attempt}) - elapsed=${elapsed}s/${timeout}s - prochain sleep=${sleep_s}s"

    # On capture l’erreur WP-CLI pour la loguer
    local out
    if out="$(wp db check 2>&1)"; then
      echo >&2 "✓ Base de données accessible (WP-CLI) après ${elapsed}s (tentatives: ${attempt})"
      return 0
    fi

    # Log du message d’échec WP-CLI (sur une ligne si possible)
    # (on tronque un peu pour ne pas spammer si c’est très verbeux)
    out="$(echo "$out" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-400)"
    echo >&2 "Échec tentative #${attempt}: ${out}"

    if [ "$elapsed" -ge "$timeout" ]; then
      echo >&2 "✗ Timeout: base de données non accessible (WP-CLI) après ${elapsed}s (tentatives: ${attempt})"
      return 1
    fi

    sleep "$sleep_s"
    elapsed=$((elapsed + sleep_s))

    # backoff progressif jusqu'à 5s
    if [ "$sleep_s" -lt 5 ]; then
      sleep_s=$((sleep_s + 1))
    fi
  done
}

main() {
  cd "$WORDPRESS_DIR"

  # Génération du wp-config.php (si nécessaire)
  generate_wp_config_if_needed || {
    echo >&2 "✗ Échec génération wp-config.php → arrêt du conteneur (exit 2)"
    exit 2
  }

  # Vérification de la variable DB
  if [ -z "${WORDPRESS_DB_HOST:-}" ]; then
    echo >&2 "✗ WORDPRESS_DB_HOST non défini → arrêt du conteneur (exit 2)"
    exit 2
  fi

  # Attente stricte de la base de données (logs détaillés)
  if ! wait_for_db_wpcli; then
    echo >&2 "✗ Base de données non accessible → arrêt du conteneur (exit 2)"
    exit 2
  fi

  # DB OK : vérification / installation WordPress
  if ! check_wordpress_installation; then
    if ! install_wordpress; then
      echo >&2 "✗ Installation WordPress échouée → arrêt du conteneur (exit 2)"
      exit 2
    fi
  fi

  # Lancement du process principal (FrankenPHP)
  exec "$@"
}
main "$@"

