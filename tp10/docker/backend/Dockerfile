FROM python:3.11-slim

# Créer un utilisateur non-root pour l'application
RUN groupadd -r -g 1000 appuser && \
    useradd -r -u 1000 -g appuser -m -d /home/appuser -s /bin/bash appuser

# Définir le répertoire de travail
WORKDIR /app

# Copier les dépendances
COPY requirements.txt .

# Installer les dépendances système nécessaires pour psycopg2
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpq5 && \
    rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Créer les répertoires nécessaires et ajuster les permissions
RUN mkdir -p /app /tmp /home/appuser && \
    chown -R appuser:appuser /app /tmp /home/appuser

# Basculer vers l'utilisateur non-root
USER appuser

# Définir le répertoire HOME pour pip
ENV HOME=/home/appuser

# Exposer le port de l'application
EXPOSE 5000

# Commande par défaut
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "app:app"]
