#!/bin/bash

# Script de construction de l'image Docker TaskFlow Backend API
# Usage: ./build-image.sh [tag]

set -e

# Variables
IMAGE_NAME="taskflow-backend-api"
TAG="${1:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# Couleurs pour l'affichage
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo -e "${YELLOW}📦 Image: ${FULL_IMAGE}${NC}"
echo ""

# Vérifier les fichiers requis
echo "🔍 Vérification des fichiers..."
for file in Dockerfile requirements.txt app.py; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Fichier manquant: $file${NC}"
        exit 1
    fi
    echo "  ✓ $file"
done
echo ""

# Construire l'image
echo "🏗️  Construction de l'image Docker..."
echo ""

docker build \
    --tag "${FULL_IMAGE}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --progress=plain \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Image construite avec succès: ${FULL_IMAGE}${NC}"
    echo ""

    # Afficher les informations de l'image
    echo "📊 Informations de l'image:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -2
    echo ""

    # Tester l'image (optionnel)
    echo -e "${YELLOW}💡 Pour tester l'image localement:${NC}"
    echo "   docker run --rm -p 5000:5000 -e DATABASE_HOST=localhost ${FULL_IMAGE}"
    echo ""

    # Instructions pour Minikube
    echo -e "${YELLOW}📝 Pour utiliser l'image avec Minikube:${NC}"
    echo ""
    echo "  1. Charger l'image dans Minikube:"
    echo "     minikube image load ${FULL_IMAGE}"
    echo ""
    echo "  2. Mettre à jour le deployment (09-backend-deployment.yaml):"
    echo "     image: ${FULL_IMAGE}"
    echo "     imagePullPolicy: Never"
    echo ""
    echo "  3. Déployer l'application:"
    echo "     kubectl apply -f 09-backend-deployment.yaml"
    echo ""

else
    echo -e "${RED}❌ Erreur lors de la construction de l'image${NC}"
    exit 1
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
