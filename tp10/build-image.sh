#!/bin/bash

# Script de construction de l'image Docker TaskFlow Backend API
# Ce script détecte automatiquement Minikube et construit l'image appropriée
# Usage: ./build-image.sh [tag]

set -e

# Variables
IMAGE_NAME="taskflow-backend"
TAG="${1:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# Couleurs pour l'affichage
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  TaskFlow Backend API - Build Script                  ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker n'est pas installé${NC}"
    echo "Installation: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${BLUE}📦 Image: ${FULL_IMAGE}${NC}"
echo ""

# Vérifier les fichiers requis
echo "🔍 Vérification des fichiers..."
MISSING_FILES=0
for file in Dockerfile requirements.txt app.py; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}  ✗ Fichier manquant: $file${NC}"
        MISSING_FILES=1
    else
        echo -e "${GREEN}  ✓ $file${NC}"
    fi
done

if [ $MISSING_FILES -eq 1 ]; then
    echo ""
    echo -e "${RED}❌ Fichiers manquants détectés${NC}"
    echo -e "${YELLOW}💡 Assurez-vous d'exécuter ce script depuis le répertoire tp10/${NC}"
    exit 1
fi
echo ""

# Détecter si Minikube est disponible et démarré
USE_MINIKUBE=false
if command -v minikube &> /dev/null; then
    if minikube status &> /dev/null; then
        echo -e "${GREEN}✅ Minikube détecté et démarré${NC}"
        USE_MINIKUBE=true

        # Configurer le shell pour utiliser le Docker daemon de Minikube
        echo "🔧 Configuration de l'environnement Docker de Minikube..."
        eval $(minikube docker-env)
        echo -e "${GREEN}✅ Environnement Docker configuré pour Minikube${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠️  Minikube est installé mais pas démarré${NC}"
        echo -e "${YELLOW}   Construction avec Docker local${NC}"
        echo ""
    fi
else
    echo -e "${BLUE}ℹ️  Minikube non détecté - construction avec Docker local${NC}"
    echo ""
fi

# Construire l'image
echo "🏗️  Construction de l'image Docker..."
echo ""

docker build \
    --tag "${FULL_IMAGE}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --progress=plain \
    .

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Image construite avec succès: ${FULL_IMAGE}${NC}"
    echo ""

    # Afficher les informations de l'image
    echo "📊 Informations de l'image:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -2
    echo ""

    # Instructions selon le contexte
    if [ "$USE_MINIKUBE" = true ]; then
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Prochaines étapes (Minikube)                         ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo "L'image est maintenant disponible dans Minikube."
        echo ""
        echo -e "${YELLOW}📝 Pour déployer l'application:${NC}"
        echo "   ./deploy.sh"
        echo ""
        echo -e "${YELLOW}💡 Configuration du deployment:${NC}"
        echo "   L'image est référencée dans 09-backend-deployment.yaml"
        echo "   imagePullPolicy: Never (utilise l'image locale)"
        echo ""
    else
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Prochaines étapes (Docker local)                     ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}💡 Pour tester l'image localement:${NC}"
        echo "   docker run --rm -p 5000:5000 \\"
        echo "     -e DATABASE_HOST=localhost \\"
        echo "     -e DATABASE_USER=taskflow \\"
        echo "     -e DATABASE_PASSWORD=taskflow2024 \\"
        echo "     ${FULL_IMAGE}"
        echo ""
        echo -e "${YELLOW}📝 Pour utiliser avec Minikube:${NC}"
        echo ""
        echo "  1. Démarrer Minikube:"
        echo "     minikube start"
        echo ""
        echo "  2. Charger l'image dans Minikube:"
        echo "     minikube image load ${FULL_IMAGE}"
        echo ""
        echo "  3. Déployer l'application:"
        echo "     ./deploy.sh"
        echo ""
    fi

    echo -e "${YELLOW}🧪 Pour exécuter les tests:${NC}"
    echo "   ./test-tp10.sh"
    echo ""

else
    echo ""
    echo -e "${RED}❌ Erreur lors de la construction de l'image${NC}"
    echo ""
    echo -e "${YELLOW}💡 Conseils de dépannage:${NC}"
    echo "  - Vérifier que tous les fichiers (Dockerfile, app.py, requirements.txt) sont présents"
    echo "  - Vérifier la syntaxe du Dockerfile"
    echo "  - Vérifier la connexion internet (pour télécharger les dépendances)"
    if [ "$USE_MINIKUBE" = true ]; then
        echo "  - Essayer de redémarrer Minikube: minikube stop && minikube start"
    fi
    echo ""
    exit 1
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
