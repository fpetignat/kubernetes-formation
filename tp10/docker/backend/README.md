# Image Docker Backend - TaskFlow API

## Description

Cette image Docker contient l'application backend Flask pour le projet TaskFlow (TP10). Elle est conçue pour être construite localement et utilisée dans Minikube.

## Structure

```
docker/backend/
├── Dockerfile          # Définition de l'image
├── requirements.txt    # Dépendances Python
└── README.md          # Ce fichier
```

## Dépendances

Les dépendances Python sont définies dans `requirements.txt` :
- **flask** : Framework web pour l'API REST
- **psycopg2-binary** : Driver PostgreSQL
- **redis** : Client Redis pour le cache
- **gunicorn** : Serveur WSGI de production

## Caractéristiques de sécurité

L'image est construite selon les meilleures pratiques de sécurité :

### ✅ Utilisateur non-root
- Utilisateur `appuser` (UID 1000, GID 1000)
- Aucune exécution en root

### ✅ Configuration sécurisée
- Système de fichiers racine en lecture seule (`readOnlyRootFilesystem: true`)
- Volumes `emptyDir` pour `/tmp` et `/home/appuser`
- Capabilities Linux supprimées (`drop: ALL`)

### ✅ Image optimisée
- Base `python:3.11-slim` (~150 MB)
- Installation des dépendances système minimales (libpq5)
- Nettoyage du cache apt
- Taille finale : ~250 MB

## Construction de l'image

### Automatique (recommandé)

```bash
# Depuis le répertoire tp10/
./build-images.sh
```

### Manuelle

```bash
# Configurer Docker pour utiliser Minikube
eval $(minikube docker-env)

# Construire l'image
cd docker/backend
docker build -t taskflow-backend:latest .

# Vérifier l'image
docker images | grep taskflow-backend
```

## Utilisation dans Kubernetes

L'image est référencée dans `09-backend-deployment.yaml` :

```yaml
containers:
- name: api
  image: taskflow-backend:latest
  imagePullPolicy: Never  # Utilise l'image locale
```

## Code de l'application

Le code de l'application (`app.py`) est monté via un ConfigMap :
- ConfigMap : `backend-app-code`
- Mount path : `/app`
- Fichier : `app.py`

Cette approche permet de modifier le code sans reconstruire l'image (utile pour le développement et la formation).

## Variables d'environnement

L'application utilise les variables d'environnement suivantes :

| Variable | Description | Source |
|----------|-------------|--------|
| `DATABASE_HOST` | Hôte PostgreSQL | ConfigMap |
| `DATABASE_PORT` | Port PostgreSQL | ConfigMap |
| `DATABASE_NAME` | Nom de la BDD | ConfigMap |
| `DATABASE_USER` | Utilisateur BDD | Secret |
| `DATABASE_PASSWORD` | Mot de passe BDD | Secret |
| `REDIS_HOST` | Hôte Redis | ConfigMap |
| `REDIS_PORT` | Port Redis | ConfigMap |
| `CACHE_TTL` | Durée de vie du cache | ConfigMap |

## Port exposé

- **Port 5000** : API REST (HTTP)

## Commande par défaut

```bash
gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 60 app:app
```

## Logs

Les logs de Gunicorn et Flask sont envoyés sur stdout/stderr et peuvent être consultés avec :

```bash
kubectl logs -n taskflow -l app=backend-api -f
```

## Dépannage

### L'image ne se construit pas

```bash
# Vérifier que Minikube est démarré
minikube status

# Vérifier la configuration Docker
eval $(minikube docker-env)
docker info
```

### Les pods ne démarrent pas

```bash
# Vérifier que l'image est disponible
docker images | grep taskflow-backend

# Vérifier les logs du pod
kubectl logs -n taskflow <pod-name>

# Décrire le pod pour voir les événements
kubectl describe pod -n taskflow <pod-name>
```

## Références

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Gunicorn Documentation](https://docs.gunicorn.org/)
- [psycopg2 Documentation](https://www.psycopg.org/docs/)
- [redis-py Documentation](https://redis-py.readthedocs.io/)
