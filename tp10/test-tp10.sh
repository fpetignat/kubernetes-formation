#!/bin/bash

# Script de test pour le TP10 - Projet de Synthèse TaskFlow
# Teste le déploiement complet, l'autoscaling et le monitoring

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TP10 - Test Projet de Synthèse TaskFlow${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

NAMESPACE="taskflow"
FAILED_TESTS=0
PASSED_TESTS=0

# Fonction pour afficher les résultats
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((FAILED_TESTS++))
    fi
}

# Test 1: Vérifier que le namespace existe
echo -e "${YELLOW}Test 1: Vérification du namespace${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_result 0 "Namespace '$NAMESPACE' existe"
else
    print_result 1 "Namespace '$NAMESPACE' n'existe pas"
    echo -e "${RED}Créez d'abord le namespace : kubectl create namespace $NAMESPACE${NC}"
    exit 1
fi
echo ""

# Test 2: Vérifier que tous les deployments sont prêts
echo -e "${YELLOW}Test 2: Vérification des deployments${NC}"
DEPLOYMENTS=("postgres" "redis" "backend-api" "frontend" "prometheus" "grafana")
for deploy in "${DEPLOYMENTS[@]}"; do
    if kubectl get deployment $deploy -n $NAMESPACE &> /dev/null; then
        READY=$(kubectl get deployment $deploy -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        DESIRED=$(kubectl get deployment $deploy -n $NAMESPACE -o jsonpath='{.spec.replicas}')
        if [ "$READY" == "$DESIRED" ] && [ "$READY" != "0" ]; then
            print_result 0 "Deployment '$deploy' est prêt ($READY/$DESIRED replicas)"
        else
            print_result 1 "Deployment '$deploy' n'est pas prêt ($READY/$DESIRED replicas)"
        fi
    else
        print_result 1 "Deployment '$deploy' n'existe pas"
    fi
done
echo ""

# Test 3: Vérifier que tous les pods sont Running
echo -e "${YELLOW}Test 3: Vérification des pods${NC}"
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$RUNNING_PODS" -ge 6 ]; then
    print_result 0 "Au moins 6 pods sont Running ($RUNNING_PODS/$TOTAL_PODS)"
else
    print_result 1 "Pas assez de pods Running ($RUNNING_PODS/$TOTAL_PODS)"
    kubectl get pods -n $NAMESPACE
fi
echo ""

# Test 4: Vérifier les PVC
echo -e "${YELLOW}Test 4: Vérification des PersistentVolumeClaims${NC}"
PVCS=("postgres-pvc" "prometheus-pvc")
for pvc in "${PVCS[@]}"; do
    STATUS=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$STATUS" == "Bound" ]; then
        print_result 0 "PVC '$pvc' est Bound"
    else
        print_result 1 "PVC '$pvc' n'est pas Bound (status: $STATUS)"
    fi
done
echo ""

# Test 5: Vérifier le HPA
echo -e "${YELLOW}Test 5: Vérification du HorizontalPodAutoscaler${NC}"
if kubectl get hpa backend-api-hpa -n $NAMESPACE &> /dev/null; then
    MIN_REPLICAS=$(kubectl get hpa backend-api-hpa -n $NAMESPACE -o jsonpath='{.spec.minReplicas}')
    MAX_REPLICAS=$(kubectl get hpa backend-api-hpa -n $NAMESPACE -o jsonpath='{.spec.maxReplicas}')
    CURRENT_REPLICAS=$(kubectl get hpa backend-api-hpa -n $NAMESPACE -o jsonpath='{.status.currentReplicas}')

    if [ "$MIN_REPLICAS" == "2" ] && [ "$MAX_REPLICAS" == "10" ]; then
        print_result 0 "HPA configuré correctement (min=$MIN_REPLICAS, max=$MAX_REPLICAS, current=$CURRENT_REPLICAS)"
    else
        print_result 1 "HPA mal configuré (min=$MIN_REPLICAS, max=$MAX_REPLICAS)"
    fi
else
    print_result 1 "HPA 'backend-api-hpa' n'existe pas"
fi
echo ""

# Test 6: Vérifier les Services
echo -e "${YELLOW}Test 6: Vérification des Services${NC}"
SERVICES=("postgres" "redis" "backend-api" "frontend" "prometheus" "grafana")
for svc in "${SERVICES[@]}"; do
    if kubectl get service $svc -n $NAMESPACE &> /dev/null; then
        TYPE=$(kubectl get service $svc -n $NAMESPACE -o jsonpath='{.spec.type}')
        print_result 0 "Service '$svc' existe (type: $TYPE)"
    else
        print_result 1 "Service '$svc' n'existe pas"
    fi
done
echo ""

# Test 7: Tester la connexion à PostgreSQL et vérifier les 1000 tâches
echo -e "${YELLOW}Test 7: Vérification de la base de données PostgreSQL${NC}"
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POSTGRES_POD" ]; then
    TASK_COUNT=$(kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U taskflow -d taskflow_db -t -c "SELECT COUNT(*) FROM tasks;" 2>/dev/null | xargs)
    if [ "$TASK_COUNT" == "1000" ]; then
        print_result 0 "PostgreSQL contient exactement 1000 tâches"
    elif [ -n "$TASK_COUNT" ]; then
        print_result 1 "PostgreSQL contient $TASK_COUNT tâches (attendu: 1000)"
    else
        print_result 1 "Impossible de compter les tâches dans PostgreSQL"
    fi
else
    print_result 1 "Pod PostgreSQL introuvable"
fi
echo ""

# Test 8: Tester l'API Backend
echo -e "${YELLOW}Test 8: Test de l'API Backend${NC}"
BACKEND_POD=$(kubectl get pod -n $NAMESPACE -l app=backend-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$BACKEND_POD" ]; then
    # Port-forward temporaire pour tester l'API
    kubectl port-forward -n $NAMESPACE $BACKEND_POD 5000:5000 &> /dev/null &
    PF_PID=$!
    sleep 3

    # Test health endpoint
    HEALTH_RESPONSE=$(curl -s http://localhost:5000/health 2>/dev/null || echo "")
    if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
        print_result 0 "API Backend /health endpoint fonctionne"
    else
        print_result 1 "API Backend /health endpoint ne répond pas correctement"
    fi

    # Test stats endpoint
    STATS_RESPONSE=$(curl -s http://localhost:5000/stats 2>/dev/null || echo "")
    if echo "$STATS_RESPONSE" | grep -q "total_tasks"; then
        TOTAL_TASKS=$(echo "$STATS_RESPONSE" | grep -o '"total_tasks":[0-9]*' | grep -o '[0-9]*')
        if [ "$TOTAL_TASKS" == "1000" ]; then
            print_result 0 "API Backend /stats retourne 1000 tâches"
        else
            print_result 1 "API Backend /stats retourne $TOTAL_TASKS tâches (attendu: 1000)"
        fi
    else
        print_result 1 "API Backend /stats ne répond pas correctement"
    fi

    # Arrêter le port-forward
    kill $PF_PID 2>/dev/null || true
else
    print_result 1 "Pod Backend API introuvable"
fi
echo ""

# Test 9: Vérifier Redis
echo -e "${YELLOW}Test 9: Vérification de Redis${NC}"
REDIS_POD=$(kubectl get pod -n $NAMESPACE -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$REDIS_POD" ]; then
    REDIS_PING=$(kubectl exec -n $NAMESPACE $REDIS_POD -- redis-cli ping 2>/dev/null || echo "")
    if [ "$REDIS_PING" == "PONG" ]; then
        print_result 0 "Redis répond correctement (PING/PONG)"
    else
        print_result 1 "Redis ne répond pas correctement"
    fi
else
    print_result 1 "Pod Redis introuvable"
fi
echo ""

# Test 10: Vérifier Prometheus
echo -e "${YELLOW}Test 10: Vérification de Prometheus${NC}"
PROMETHEUS_POD=$(kubectl get pod -n $NAMESPACE -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PROMETHEUS_POD" ]; then
    # Vérifier que Prometheus est en cours d'exécution
    PROMETHEUS_READY=$(kubectl get pod -n $NAMESPACE $PROMETHEUS_POD -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$PROMETHEUS_READY" == "True" ]; then
        print_result 0 "Prometheus est prêt"
    else
        print_result 1 "Prometheus n'est pas prêt"
    fi
else
    print_result 1 "Pod Prometheus introuvable"
fi
echo ""

# Test 11: Vérifier Metrics Server (requis pour HPA)
echo -e "${YELLOW}Test 11: Vérification de Metrics Server${NC}"
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    METRICS_READY=$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$METRICS_READY" -ge 1 ]; then
        print_result 0 "Metrics Server est déployé et prêt"
    else
        print_result 1 "Metrics Server n'est pas prêt"
    fi
else
    print_result 1 "Metrics Server n'est pas installé (requis pour HPA)"
    echo -e "${YELLOW}   → Installez avec: minikube addons enable metrics-server${NC}"
fi
echo ""

# Test 12: Vérifier les ConfigMaps et Secrets
echo -e "${YELLOW}Test 12: Vérification des ConfigMaps et Secrets${NC}"
CONFIGMAPS=("postgres-init-script" "backend-config" "backend-app-code" "frontend-html" "prometheus-config")
for cm in "${CONFIGMAPS[@]}"; do
    if kubectl get configmap $cm -n $NAMESPACE &> /dev/null; then
        print_result 0 "ConfigMap '$cm' existe"
    else
        print_result 1 "ConfigMap '$cm' n'existe pas"
    fi
done

if kubectl get secret postgres-secret -n $NAMESPACE &> /dev/null; then
    print_result 0 "Secret 'postgres-secret' existe"
else
    print_result 1 "Secret 'postgres-secret' n'existe pas"
fi
echo ""

# Résumé final
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Résumé des tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Tests réussis : $PASSED_TESTS${NC}"
echo -e "${RED}Tests échoués : $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ Tous les tests sont passés ! Le TP10 est correctement déployé.${NC}"
    echo ""
    echo -e "${YELLOW}Prochaines étapes :${NC}"
    echo "1. Accéder au frontend : minikube service frontend -n taskflow"
    echo "2. Accéder à Grafana : minikube service grafana -n taskflow (admin/admin2024)"
    echo "3. Lancer le load generator : kubectl apply -f 22-load-generator.yaml"
    echo "4. Observer le HPA : watch kubectl get hpa -n taskflow"
    exit 0
else
    echo -e "${RED}✗ Certains tests ont échoué. Vérifiez les erreurs ci-dessus.${NC}"
    echo ""
    echo -e "${YELLOW}Commandes de débogage utiles :${NC}"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl describe pod <POD_NAME> -n $NAMESPACE"
    echo "  kubectl logs <POD_NAME> -n $NAMESPACE"
    exit 1
fi
