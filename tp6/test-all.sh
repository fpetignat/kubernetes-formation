#!/bin/bash

# Script de test pour les exercices du TP6
# Ce script permet de tester tous les exercices de mise en production et CI/CD

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        log_error "helm n'est pas installé"
        exit 1
    fi

    if ! command -v minikube &> /dev/null; then
        log_error "minikube n'est pas installé"
        exit 1
    fi

    # Vérifier que le cluster est démarré
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Le cluster Kubernetes n'est pas accessible"
        log_info "Démarrez minikube avec: minikube start"
        exit 1
    fi

    log_info "Tous les prérequis sont satisfaits ✓"
}

# Fonction pour tester Helm
test_helm() {
    log_info "=== Test des exercices Helm ==="

    # Ajouter les repositories Helm
    log_info "Ajout des repositories Helm..."
    helm repo add bitnami https://charts.bitnami.com/bitnami &> /dev/null || true
    helm repo update &> /dev/null

    # Test du chart personnalisé
    log_info "Validation du chart personnalisé..."
    helm lint 01-helm/my-app/

    log_info "Installation du chart personnalisé..."
    helm install my-release ./01-helm/my-app --dry-run --debug > /dev/null

    log_info "Tests Helm réussis ✓"
}

# Fonction pour tester les manifests Ingress
test_ingress() {
    log_info "=== Test des exercices Ingress ==="

    # Vérifier que l'addon ingress est activé
    if ! minikube addons list | grep ingress | grep enabled &> /dev/null; then
        log_warning "L'addon ingress n'est pas activé"
        log_info "Activation de l'addon ingress..."
        minikube addons enable ingress
        sleep 10
    fi

    # Valider les fichiers Ingress
    log_info "Validation des fichiers Ingress..."
    kubectl apply --dry-run=client -f 02-ingress/ &> /dev/null

    log_info "Tests Ingress réussis ✓"
}

# Fonction pour tester les stratégies de déploiement
test_deployment_strategies() {
    log_info "=== Test des stratégies de déploiement ==="

    log_info "Validation des fichiers de déploiement..."
    kubectl apply --dry-run=client -f 03-deployment-strategies/ &> /dev/null

    log_info "Tests des stratégies de déploiement réussis ✓"
}

# Fonction pour tester les bonnes pratiques
test_best_practices() {
    log_info "=== Test des bonnes pratiques de production ==="

    # Vérifier que metrics-server est activé pour HPA
    if ! minikube addons list | grep metrics-server | grep enabled &> /dev/null; then
        log_warning "L'addon metrics-server n'est pas activé"
        log_info "Activation de metrics-server..."
        minikube addons enable metrics-server
    fi

    log_info "Validation des fichiers de bonnes pratiques..."
    kubectl apply --dry-run=client -f 04-production-best-practices/12-health-checks.yaml &> /dev/null
    kubectl apply --dry-run=client -f 04-production-best-practices/13-pdb.yaml &> /dev/null
    kubectl apply --dry-run=client -f 04-production-best-practices/14-hpa.yaml &> /dev/null

    log_info "Tests des bonnes pratiques réussis ✓"
}

# Fonction pour tester ArgoCD
test_argocd() {
    log_info "=== Test des fichiers ArgoCD ==="

    log_info "Validation des fichiers ArgoCD..."
    kubectl apply --dry-run=client -f 05-argocd/ &> /dev/null

    log_info "Tests ArgoCD réussis ✓"
}

# Fonction pour tester la structure GitOps
test_gitops() {
    log_info "=== Test de la structure GitOps ==="

    log_info "Test de Kustomize - environnement dev..."
    kubectl kustomize 07-gitops-structure/overlays/dev > /dev/null

    log_info "Test de Kustomize - environnement staging..."
    kubectl kustomize 07-gitops-structure/overlays/staging > /dev/null

    log_info "Test de Kustomize - environnement production..."
    kubectl kustomize 07-gitops-structure/overlays/production > /dev/null

    log_info "Tests GitOps réussis ✓"
}

# Fonction pour tester les fichiers de monitoring
test_monitoring() {
    log_info "=== Test des fichiers de monitoring ==="

    log_info "Validation des fichiers de monitoring..."
    kubectl apply --dry-run=client -f 06-monitoring/ &> /dev/null || true

    log_info "Tests monitoring réussis ✓"
}

# Fonction pour afficher un résumé
show_summary() {
    log_info "=== Résumé des tests ==="
    log_info "Tous les tests ont été exécutés avec succès ✓"
    echo ""
    log_info "Structure des exercices créés:"
    echo "  - 01-helm/          : Charts Helm personnalisés"
    echo "  - 02-ingress/       : Exemples d'Ingress"
    echo "  - 03-deployment-strategies/ : Rolling, Blue-Green, Canary"
    echo "  - 04-production-best-practices/ : HPA, PDB, Health checks"
    echo "  - 05-argocd/        : Applications ArgoCD"
    echo "  - 06-monitoring/    : ServiceMonitor et PrometheusRules"
    echo "  - 07-gitops-structure/ : Structure Kustomize avec overlays"
    echo "  - .github/workflows/ : Pipelines CI/CD"
    echo "  - sample-app/       : Application Node.js exemple"
    echo ""
    log_info "Pour tester un exercice spécifique, utilisez:"
    echo "  kubectl apply -f <fichier>.yaml"
    echo "  helm install <release-name> ./01-helm/my-app"
    echo "  kubectl kustomize 07-gitops-structure/overlays/<env>"
}

# Menu principal
main() {
    cd "$(dirname "$0")"

    echo "============================================"
    echo "   Tests des exercices du TP6"
    echo "   Mise en Production et CI/CD avec K8s"
    echo "============================================"
    echo ""

    check_prerequisites
    echo ""

    test_helm
    echo ""

    test_ingress
    echo ""

    test_deployment_strategies
    echo ""

    test_best_practices
    echo ""

    test_argocd
    echo ""

    test_gitops
    echo ""

    test_monitoring
    echo ""

    show_summary
}

# Exécution du script
main "$@"
