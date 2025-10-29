#!/bin/bash

# Script d'installation des workflows GitHub Actions
# Ce script copie les workflows dans .github/workflows/

set -e

echo "======================================================================"
echo "Installation des workflows GitHub Actions pour kubernetes-formation"
echo "======================================================================"
echo ""

# Vérifier qu'on est à la racine du projet
if [ ! -f "README.md" ] || [ ! -d "tp1" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis la racine du projet kubernetes-formation"
    exit 1
fi

# Créer le dossier .github/workflows s'il n'existe pas
echo "📁 Création du dossier .github/workflows..."
mkdir -p .github/workflows

# Copier les fichiers
echo "📋 Copie des fichiers de workflow..."

if [ -f "github-workflows-setup/test-kubernetes-manifests.yml" ]; then
    cp github-workflows-setup/test-kubernetes-manifests.yml .github/workflows/
    echo "  ✓ test-kubernetes-manifests.yml copié"
else
    echo "  ⚠️  test-kubernetes-manifests.yml non trouvé"
fi

if [ -f "github-workflows-setup/README.md" ]; then
    cp github-workflows-setup/README.md .github/workflows/
    echo "  ✓ README.md copié"
else
    echo "  ⚠️  README.md non trouvé"
fi

echo ""
echo "======================================================================"
echo "✅ Installation terminée !"
echo "======================================================================"
echo ""
echo "Les workflows GitHub Actions ont été installés dans .github/workflows/"
echo ""
echo "Prochaines étapes :"
echo "  1. Vérifier les fichiers installés : ls -la .github/workflows/"
echo "  2. Ajouter et committer les changements :"
echo "     git add .github/ README.md"
echo "     git commit -m 'Add GitHub Actions tests for Kubernetes formation'"
echo "  3. Pousser vers GitHub :"
echo "     git push origin \$(git branch --show-current)"
echo ""
echo "Les tests s'exécuteront automatiquement à chaque push ou pull request."
echo ""
echo "Pour plus d'informations, consultez .github/workflows/README.md"
echo ""
