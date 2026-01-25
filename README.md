# WordPress FrankenPHP

![License](https://img.shields.io/github/license/Gskill75/wordpress-frankenphp)
![Docker](https://img.shields.io/badge/docker-ready-blue)
![Kubernetes](https://img.shields.io/badge/kubernetes-ready-326CE5)
![OpenShift](https://img.shields.io/badge/openshift-ready-EE0000)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen)](https://github.com/renovatebot/renovate)

Image Docker WordPress optimisée basée sur [FrankenPHP](https://frankenphp.dev/) avec installation automatique, exécution rootless et support complet pour Kubernetes/OpenShift.

## Caractéristiques

- **FrankenPHP 1.11** avec PHP 8.4
- **Rootless** : UID 1000, compatible OpenShift (arbitrary UID)
- **Installation automatique** de WordPress au premier démarrage
- **WP-CLI** intégré pour la gestion en ligne de commande
- **Extensions PHP** optimisées : bcmath, exif, gd, intl, mysqli, zip, imagick, opcache
- **OPcache configuré** pour des performances maximales
- **Port 8080** : pas de capabilities requises
- **Renovate** : mises à jour automatiques des dépendances

## Installation rapide

### Avec Docker Compose

```bash
git clone https://github.com/Gskill75/wordpress-frankenphp.git
cd wordpress-frankenphp

cp .env.example .env
vim .env

docker-compose up -d
docker-compose logs -f wordpress
```

Accédez à WordPress sur [http://localhost:8080](http://localhost:8080)

### Avec Docker CLI

```bash
# Construire l'image
docker build -t wordpress-frankenphp .

# Démarrer MySQL
docker run -d --name mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wordpress \
  -e MYSQL_PASSWORD=wordpress \
  mysql:8.0

# Démarrer WordPress
docker run -d --name wordpress \
  --link mysql:mysql \
  -p 8080:8080 \
  -e SERVER_NAME=:8080 \
  -e WORDPRESS_DB_HOST=mysql:3306 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=wordpress \
  -e WORDPRESS_URL=http://localhost:8080 \
  -e WORDPRESS_ADMIN_USER=admin \
  -e WORDPRESS_ADMIN_PASSWORD=SecurePass123! \
  -e WORDPRESS_ADMIN_EMAIL=admin@example.com \
  wordpress-frankenphp
```

## Variables d'environnement

### Base de données (requis)

| Variable | Description | Défaut |
|----------|-------------|--------|
| `WORDPRESS_DB_HOST` | Hôte de la base de données | - |
| `WORDPRESS_DB_NAME` | Nom de la base de données | - |
| `WORDPRESS_DB_USER` | Utilisateur de la base de données | - |
| `WORDPRESS_DB_PASSWORD` | Mot de passe de la base de données | - |

### Installation automatique

| Variable | Description | Défaut |
|----------|-------------|--------|
| `WORDPRESS_URL` | URL du site WordPress | `http://localhost` |
| `WORDPRESS_TITLE` | Titre du site | `Mon Site WordPress` |
| `WORDPRESS_ADMIN_USER` | Nom d'utilisateur admin | `admin` |
| `WORDPRESS_ADMIN_PASSWORD` | Mot de passe admin | *Généré automatiquement* |
| `WORDPRESS_ADMIN_EMAIL` | Email de l'administrateur | `admin@example.com` |
| `WORDPRESS_LOCALE` | Langue de WordPress | `fr_FR` |

### Configuration optionnelle

| Variable | Description | Défaut |
|----------|-------------|--------|
| `SERVER_NAME` | Configuration du port Caddy | `:8080` |
| `WORDPRESS_TIMEZONE` | Fuseau horaire | - |
| `WORDPRESS_PERMALINK_STRUCTURE` | Structure des permaliens | - |
| `WORDPRESS_AUTO_UPDATE` | Mises à jour automatiques | `true` |
| `WORDPRESS_DB_WAIT_TIMEOUT` | Timeout attente DB (secondes) | `180` |

## Utilisation

### Docker Compose

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Arrêter et supprimer les volumes
docker-compose down -v

# Voir les logs
docker-compose logs -f

# Exécuter WP-CLI
docker-compose exec wordpress wp plugin list
```

### WP-CLI

```bash
# Lister les plugins
docker-compose exec wordpress wp plugin list

# Installer un plugin
docker-compose exec wordpress wp plugin install akismet --activate

# Mettre à jour WordPress
docker-compose exec wordpress wp core update

# Export de la base de données
docker-compose exec wordpress wp db export - > backup.sql

# Import de la base de données
docker-compose exec -T wordpress wp db import - < backup.sql
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 0
        fsGroup: 0
      containers:
      - name: wordpress
        image: ghcr.io/gskill75/wordpress-frankenphp:latest
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          readOnlyRootFilesystem: false
        ports:
        - containerPort: 8080
        env:
        - name: SERVER_NAME
          value: ":8080"
        - name: WORDPRESS_DB_HOST
          value: "mysql-service:3306"
        - name: WORDPRESS_DB_NAME
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db-name
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db-user
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db-password
        - name: WORDPRESS_URL
          value: "https://mon-site.example.com"
        - name: WORDPRESS_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: admin-user
        - name: WORDPRESS_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: admin-password
        - name: WORDPRESS_ADMIN_EMAIL
          value: "admin@example.com"
        volumeMounts:
        - name: wordpress-storage
          mountPath: /app/public/wp-content
        livenessProbe:
          httpGet:
            path: /wp-admin/install.php
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /wp-admin/install.php
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
spec:
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

## Architecture

### Stack technique

- **Base** : FrankenPHP 1.11 (Caddy + PHP 8.4)
- **WordPress** : 6.9 (configurable via `--build-arg WORDPRESS_VERSION`)
- **Extensions PHP** : bcmath, exif, gd, intl, mysqli, zip, imagick, opcache

### Rootless

L'image s'exécute sans privilèges root :

| Propriété | Valeur |
|-----------|--------|
| UID | 1000 (configurable via `--build-arg UID`) |
| GID | 0 (root group pour compatibilité OpenShift) |
| Port | 8080 (pas de capabilities requises) |
| Home | `/app` |

Les permissions utilisent le pattern `chmod g=u` permettant à n'importe quel UID du groupe root d'écrire (compatibilité OpenShift arbitrary UID).

### Volumes

| Path | Description |
|------|-------------|
| `/app/public/wp-content` | Contenu WordPress (thèmes, plugins, uploads) |
| `/config/caddy` | Configuration Caddy |
| `/data/caddy` | Données Caddy (certificats) |

### Structure du projet

```
.
├── .github/
│   └── workflows/        # CI/CD Docker build & push
├── Dockerfile            # Image rootless WordPress FrankenPHP
├── entrypoint.sh         # Script d'installation automatique
├── docker-compose.yml    # Stack de développement
├── renovate.json         # Configuration Renovate Bot
├── .env.example          # Variables d'environnement exemple
└── README.md
```

## Développement

### Build local

```bash
# Build standard
docker build -t wordpress-frankenphp:dev .

# Build avec arguments personnalisés
docker build \
  --build-arg WORDPRESS_VERSION=6.9 \
  --build-arg UID=1000 \
  -t wordpress-frankenphp:dev .
```

### Tests

```bash
docker-compose up -d
curl -I http://localhost:8080
docker-compose exec wordpress wp --info
docker-compose exec wordpress php -m
```

## Sécurité

- **Rootless** : Exécution sans privilèges (UID 1000)
- **Pas de capabilities** : Aucune capability Linux requise
- **OpenShift ready** : Compatible avec les politiques de sécurité strictes
- **Secrets** : Utilisez Kubernetes Secrets ou Docker Secrets en production
- **HTTPS** : Configurez un reverse proxy ou Ingress pour TLS

## Mises à jour automatiques

[Renovate Bot](https://github.com/renovatebot/renovate) gère automatiquement les mises à jour :

- **GitHub Actions** : PRs groupées hebdomadaires
- **FrankenPHP** : Image Docker de base
- **WordPress** : Version dans le Dockerfile (auto-merge pour les patches)

## Liens utiles

- [FrankenPHP Documentation](https://frankenphp.dev/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [WP-CLI Documentation](https://wp-cli.org/)

## Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Commiter vos changements (`git commit -am 'Ajout d'une fonctionnalité'`)
4. Pousser vers la branche (`git push origin feature/ma-fonctionnalite`)
5. Créer une Pull Request

## Licence

MIT - Voir [LICENSE](LICENSE)
