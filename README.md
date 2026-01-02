# WordPress FrankenPHP

![License](https://img.shields.io/github/license/Gskill75/wordpress-frankenphp)
![Docker](https://img.shields.io/badge/docker-ready-blue)
![Kubernetes](https://img.shields.io/badge/kubernetes-ready-326CE5)

Image Docker WordPress optimisée basée sur [FrankenPHP](https://frankenphp.dev/) avec installation automatique et support complet pour Kubernetes.

## 🚀 Caractéristiques

- **FrankenPHP 1.11** avec PHP 8.4
- **Installation automatique** de WordPress au premier démarrage
- **WP-CLI** intégré pour la gestion en ligne de commande
- **Extensions PHP** optimisées : bcmath, exif, gd, intl, mysqli, zip, imagick, opcache
- **OPcache configuré** pour des performances maximales
- **Support multi-tenant** pour WordPress-as-a-Service
- **Compatible Kubernetes** avec healthchecks et configuration via variables d'environnement

## 📚 Table des matières

- [Installation rapide](#-installation-rapide)
- [Variables d'environnement](#-variables-denvironnement)
- [Utilisation](#-utilisation)
  - [Docker Compose](#docker-compose)
  - [Docker CLI](#docker-cli)
  - [Kubernetes](#kubernetes)
- [Fonctionnalités avancées](#-fonctionnalités-avancées)
- [Développement](#-développement)
- [Architecture](#-architecture)

## ⚡ Installation rapide

### Avec Docker Compose

```bash
# Cloner le repository
git clone https://github.com/Gskill75/wordpress-frankenphp.git
cd wordpress-frankenphp

# Copier et éditer la configuration
cp .env.example .env
vim .env

# Démarrer la stack
docker-compose up -d

# Voir les logs d'installation
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
  -p 8080:80 \
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

## 🛠️ Variables d'environnement

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
| `WORDPRESS_TIMEZONE` | Fuseau horaire | - |
| `WORDPRESS_PERMALINK_STRUCTURE` | Structure des permaliens | - |
| `WORDPRESS_AUTO_UPDATE` | Mises à jour automatiques | `true` |

## 💻 Utilisation

### Docker Compose

Le fichier `docker-compose.yml` fourni est prêt pour le développement local :

```yaml
services:
  wordpress:
    build: .
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: mysql:3306
      WORDPRESS_URL: http://localhost:8080
      # ... autres variables
    volumes:
      - wordpress_data:/app/public/wp-content
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    # ... configuration MySQL
```

**Commandes utiles :**

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Arrêter et supprimer les volumes
docker-compose down -v

# Voir les logs
docker-compose logs -f

# Redémarrer WordPress
docker-compose restart wordpress

# Exécuter WP-CLI
docker-compose exec wordpress wp --help
```

### Docker CLI

```bash
# Construire l'image
docker build -t wordpress-frankenphp:latest .

# Lancer avec variables d'environnement
docker run -d \
  --name my-wordpress \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=mysql:3306 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=wordpress \
  -v wordpress_data:/app/public/wp-content \
  wordpress-frankenphp:latest

# Accéder au conteneur
docker exec -it my-wordpress bash

# Utiliser WP-CLI
docker exec my-wordpress wp plugin list --allow-root
```

### Kubernetes

#### Deployment exemple

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
      containers:
      - name: wordpress
        image: ghcr.io/gskill75/wordpress-frankenphp:latest
        ports:
        - containerPort: 80
        env:
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
        - name: WORDPRESS_TITLE
          value: "Mon Site"
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
        - name: WORDPRESS_LOCALE
          value: "fr_FR"
        - name: WORDPRESS_TIMEZONE
          value: "Europe/Paris"
        - name: WORDPRESS_PERMALINK_STRUCTURE
          value: "/%postname%/"
        volumeMounts:
        - name: wordpress-storage
          mountPath: /app/public/wp-content
        livenessProbe:
          httpGet:
            path: /wp-admin/install.php
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /wp-admin/install.php
            port: 80
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
    targetPort: 80
  type: ClusterIP
```

#### ConfigMap pour configuration avancée

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wordpress-config
data:
  WORDPRESS_LOCALE: "fr_FR"
  WORDPRESS_TIMEZONE: "Europe/Paris"
  WORDPRESS_PERMALINK_STRUCTURE: "/%postname%/"
  WORDPRESS_AUTO_UPDATE: "false"
```

## 💡 Fonctionnalités avancées

### Installation automatique intelligente

L'entrypoint vérifie automatiquement si WordPress est installé :

1. **Vérification de la base de données** : Attend jusqu'à 30 secondes que MySQL soit prêt
2. **Détection de l'installation** : Utilise WP-CLI pour vérifier si WordPress est déjà configuré
3. **Installation si nécessaire** : Configure WordPress complètement avec les paramètres fournis
4. **Idempotence** : Peut être relancé sans risque de réinstallation

### Utilisation de WP-CLI

```bash
# Lister les plugins
docker-compose exec wordpress wp plugin list --allow-root

# Installer un plugin
docker-compose exec wordpress wp plugin install akismet --activate --allow-root

# Mettre à jour WordPress
docker-compose exec wordpress wp core update --allow-root

# Créer un utilisateur
docker-compose exec wordpress wp user create john john@example.com --role=editor --allow-root

# Export de la base de données
docker-compose exec wordpress wp db export - --allow-root > backup.sql

# Import de la base de données
docker-compose exec -T wordpress wp db import - --allow-root < backup.sql
```

### Optimisations OPcache

OPcache est préconfiguré pour des performances optimales :

```ini
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=2
opcache.validate_timestamps=1
```

### Gestion des erreurs

Les erreurs PHP sont loguées dans stderr pour une intégration facile avec les systèmes de monitoring :

```bash
# Voir les logs d'erreur PHP
docker-compose logs wordpress | grep -i error
```

## 🔧 Développement

### Build local

```bash
# Build de l'image
docker build -t wordpress-frankenphp:dev .

# Build avec arguments
docker build \
  --build-arg WORDPRESS_VERSION=6.9 \
  --build-arg USER=appuser \
  -t wordpress-frankenphp:dev .
```

### Tests

```bash
# Démarrer l'environnement de test
docker-compose up -d

# Vérifier l'installation
curl -I http://localhost:8080

# Tester WP-CLI
docker-compose exec wordpress wp --info --allow-root

# Vérifier les extensions PHP
docker-compose exec wordpress php -m
```

### Structure du projet

```
.
├── .github/              # GitHub Actions workflows
├── Dockerfile            # Image WordPress FrankenPHP
├── entrypoint.sh         # Script d'installation automatique
├── docker-compose.yml    # Stack de développement
├── .env.example          # Variables d'environnement exemple
├── LICENSE               # Licence MIT
└── README.md             # Cette documentation
```

## 🏛️ Architecture

### Stack technique

- **Base** : FrankenPHP 1.11 (Caddy + PHP 8.4)
- **WordPress** : 6.9 (configurable)
- **Extensions PHP** : bcmath, exif, gd, intl, mysqli, zip, imagick, opcache
- **Outils** : WP-CLI pour l'automatisation

### Ports exposés

- `80/tcp` : HTTP (FrankenPHP/Caddy)

### Volumes

- `/app/public/wp-content` : Contenu WordPress (thèmes, plugins, uploads)
- `/config/caddy` : Configuration Caddy (optionnel)
- `/data/caddy` : Données Caddy (certificats, etc.)

### Utilisateur

Par défaut, l'application s'exécute sous l'utilisateur `appuser` (non-root) pour plus de sécurité.

## 📝 Notes de sécurité

- **Secrets** : Utilisez des Kubernetes Secrets ou Docker Secrets en production
- **HTTPS** : FrankenPHP supporte HTTPS automatique avec Let's Encrypt
- **Mots de passe** : Utilisez des mots de passe forts (min. 12 caractères)
- **Updates** : Maintenez WordPress et les plugins à jour
- **Non-root** : L'application s'exécute avec un utilisateur non-privilégié

## 🔗 Liens utiles

- [FrankenPHP Documentation](https://frankenphp.dev/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [WP-CLI Documentation](https://wp-cli.org/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 👥 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Commiter vos changements (`git commit -am 'Ajout d\'une fonctionnalité'`)
4. Pousser vers la branche (`git push origin feature/ma-fonctionnalite`)
5. Créer une Pull Request

## 📝 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## ❤️ Remerciements

- [FrankenPHP](https://frankenphp.dev/) pour le serveur d'applications PHP moderne
- [WordPress](https://wordpress.org/) pour le CMS
- [WP-CLI](https://wp-cli.org/) pour l'outil en ligne de commande

---

Développé avec ❤️ pour WordPress-as-a-Service sur Kubernetes