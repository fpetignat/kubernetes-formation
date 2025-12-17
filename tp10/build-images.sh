#!/bin/bash

# Script de construction des images Docker pour le TP10
# Ce script construit l'image backend et la rend disponible dans Minikube

set -e

echo "=================================================="
echo "Construction des images Docker pour le TP10"
echo "=================================================="
echo ""

# Vérifier que Minikube est démarré
if ! minikube status &> /dev/null; then
    echo "❌ Erreur : Minikube n'est pas démarré"
    echo "   Veuillez démarrer Minikube avec : minikube start"
    exit 1
fi

echo "✅ Minikube est démarré"
echo ""

# Configurer le shell pour utiliser le Docker daemon de Minikube
echo "📦 Configuration de l'environnement Docker de Minikube..."
eval $(minikube docker-env)
echo "✅ Environnement Docker configuré"
echo ""

# Construire l'image backend
echo "🔨 Construction de l'image backend-api..."
echo "   Base: python:3.11-slim"
echo "   Nom: taskflow-backend:latest"
echo ""

cd docker/backend
docker build -t taskflow-backend:latest .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Image backend-api construite avec succès"
else
    echo ""
    echo "❌ Erreur lors de la construction de l'image backend-api"
    exit 1
fi

cd ../..

# Vérifier que l'image est disponible
echo ""
echo "🔍 Vérification de l'image construite..."
docker images | grep taskflow-backend

echo ""
echo "=================================================="
echo "✅ Construction terminée avec succès !"
echo "=================================================="
echo ""
echo "📝 Notes importantes :"
echo "   - L'image taskflow-backend:latest est disponible dans Minikube"
echo "   - Vous pouvez maintenant déployer l'application avec ./deploy.sh"
echo "   - L'image sera utilisée par le deployment 09-backend-deployment.yaml"
echo ""
echo "💡 Conseil :"
echo "   Si vous modifiez le code de l'application, relancez ce script"
echo "   pour reconstruire l'image avec les dernières modifications"
echo ""
