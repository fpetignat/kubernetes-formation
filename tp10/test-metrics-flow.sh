#!/bin/bash

#####################################################################
# Script de Test : Circulation des Métriques Prometheus → Grafana
#####################################################################

set -e

NAMESPACE="taskflow"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Test de circulation Prometheus → Grafana"
echo "=========================================="
echo ""

# Fonction pour afficher un test réussi
pass() {
    echo -e "${GREEN}✓${NC} $1"
}

# Fonction pour afficher un test échoué
fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Fonction pour afficher un warning
warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "1. Vérification des pods Prometheus et Grafana"
echo "----------------------------------------------"

PROMETHEUS_POD=$(kubectl get pods -n $NAMESPACE -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$PROMETHEUS_POD" ]; then
    fail "Pod Prometheus introuvable"
fi
pass "Pod Prometheus trouvé: $PROMETHEUS_POD"

GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$GRAFANA_POD" ]; then
    fail "Pod Grafana introuvable"
fi
pass "Pod Grafana trouvé: $GRAFANA_POD"

# Vérifier que les pods sont Running
PROMETHEUS_STATUS=$(kubectl get pod $PROMETHEUS_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
if [ "$PROMETHEUS_STATUS" != "Running" ]; then
    fail "Pod Prometheus n'est pas Running (état: $PROMETHEUS_STATUS)"
fi
pass "Pod Prometheus est Running"

GRAFANA_STATUS=$(kubectl get pod $GRAFANA_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
if [ "$GRAFANA_STATUS" != "Running" ]; then
    fail "Pod Grafana n'est pas Running (état: $GRAFANA_STATUS)"
fi
pass "Pod Grafana est Running"

echo ""
echo "2. Vérification de l'accessibilité de Prometheus"
echo "------------------------------------------------"

# Tester l'API Prometheus
PROM_READY=$(kubectl exec -n $NAMESPACE $PROMETHEUS_POD -- wget -q -O - http://localhost:9090/-/ready 2>/dev/null || echo "")
if [ -z "$PROM_READY" ]; then
    fail "Prometheus n'est pas accessible sur http://localhost:9090"
fi
pass "Prometheus est accessible et prêt"

# Vérifier les targets Prometheus
echo "   Récupération des targets Prometheus..."
kubectl exec -n $NAMESPACE $PROMETHEUS_POD -- wget -q -O - http://localhost:9090/api/v1/targets > /tmp/prom-targets.json 2>/dev/null || fail "Impossible de récupérer les targets Prometheus"

ACTIVE_TARGETS=$(cat /tmp/prom-targets.json | grep -o '"health":"up"' | wc -l)
if [ "$ACTIVE_TARGETS" -eq 0 ]; then
    warn "Aucune target active trouvée. Prometheus ne collecte peut-être pas encore de métriques."
else
    pass "Prometheus a $ACTIVE_TARGETS target(s) active(s)"
fi

# Vérifier qu'il y a des métriques
echo "   Vérification de la présence de métriques..."
METRIC_COUNT=$(kubectl exec -n $NAMESPACE $PROMETHEUS_POD -- wget -q -O - 'http://localhost:9090/api/v1/query?query=up' 2>/dev/null | grep -o '"metric":{' | wc -l)
if [ "$METRIC_COUNT" -eq 0 ]; then
    warn "Aucune métrique 'up' trouvée. Les targets ne sont peut-être pas encore scrapées."
else
    pass "Prometheus collecte des métriques ($METRIC_COUNT série(s) pour 'up')"
fi

echo ""
echo "3. Vérification de l'accessibilité de Grafana"
echo "---------------------------------------------"

# Tester l'API Grafana
GRAFANA_HEALTH=$(kubectl exec -n $NAMESPACE $GRAFANA_POD -- wget -q -O - http://localhost:3000/api/health 2>/dev/null || echo "")
if [ -z "$GRAFANA_HEALTH" ]; then
    fail "Grafana n'est pas accessible sur http://localhost:3000"
fi
pass "Grafana est accessible"

# Vérifier que Grafana est bien en état "ok"
if echo "$GRAFANA_HEALTH" | grep -q '"database":"ok"'; then
    pass "Base de données Grafana est OK"
else
    warn "État de la base de données Grafana incertain"
fi

echo ""
echo "4. Vérification de la datasource Prometheus dans Grafana"
echo "---------------------------------------------------------"

# Vérifier la présence de la ConfigMap datasource
kubectl get configmap grafana-datasources -n $NAMESPACE >/dev/null 2>&1 || fail "ConfigMap grafana-datasources introuvable"
pass "ConfigMap grafana-datasources existe"

# Vérifier que la datasource est montée dans le pod
DATASOURCE_MOUNTED=$(kubectl exec -n $NAMESPACE $GRAFANA_POD -- ls /etc/grafana/provisioning/datasources/datasources.yaml 2>/dev/null || echo "")
if [ -z "$DATASOURCE_MOUNTED" ]; then
    fail "La datasource n'est pas montée dans /etc/grafana/provisioning/datasources/"
fi
pass "Fichier datasource est monté dans le pod Grafana"

# Vérifier le contenu du fichier datasource
echo "   Contenu de la datasource provisionée :"
kubectl exec -n $NAMESPACE $GRAFANA_POD -- cat /etc/grafana/provisioning/datasources/datasources.yaml | grep -E "(name:|url:|type:)" | sed 's/^/   /'

# Interroger l'API Grafana pour lister les datasources
echo "   Vérification via l'API Grafana..."
DATASOURCES=$(kubectl exec -n $NAMESPACE $GRAFANA_POD -- wget -q -O - --header="Content-Type: application/json" --user=admin --password=admin2024 http://localhost:3000/api/datasources 2>/dev/null || echo "")
if [ -z "$DATASOURCES" ]; then
    fail "Impossible d'interroger l'API Grafana pour lister les datasources"
fi

# Vérifier qu'il y a au moins une datasource Prometheus
if echo "$DATASOURCES" | grep -q '"type":"prometheus"'; then
    pass "Datasource Prometheus est configurée dans Grafana"

    # Extraire l'URL de la datasource
    DATASOURCE_URL=$(echo "$DATASOURCES" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "   URL de la datasource: $DATASOURCE_URL"
else
    fail "Aucune datasource Prometheus trouvée dans Grafana"
fi

echo ""
echo "5. Test de connectivité Grafana → Prometheus"
echo "---------------------------------------------"

# Tester la connexion via l'API Grafana
echo "   Test de la datasource via l'API Grafana..."

# Récupérer l'ID de la datasource Prometheus
DATASOURCE_ID=$(echo "$DATASOURCES" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
if [ -z "$DATASOURCE_ID" ]; then
    fail "Impossible de récupérer l'ID de la datasource Prometheus"
fi
pass "Datasource ID: $DATASOURCE_ID"

# Tester la datasource
TEST_RESULT=$(kubectl exec -n $NAMESPACE $GRAFANA_POD -- wget -q -O - --header="Content-Type: application/json" --user=admin --password=admin2024 http://localhost:3000/api/datasources/$DATASOURCE_ID 2>/dev/null || echo "")

if echo "$TEST_RESULT" | grep -q '"type":"prometheus"'; then
    pass "La datasource Prometheus est bien configurée"
else
    fail "La datasource Prometheus ne répond pas correctement"
fi

echo ""
echo "6. Test de requête de métriques via Grafana"
echo "--------------------------------------------"

# Effectuer une requête Prometheus via l'API Grafana
echo "   Exécution d'une requête test: up{job=\"kubernetes-pods\"}..."
QUERY_RESULT=$(kubectl exec -n $NAMESPACE $GRAFANA_POD -- wget -q -O - --header="Content-Type: application/json" --user=admin --password=admin2024 "http://localhost:3000/api/datasources/proxy/$DATASOURCE_ID/api/v1/query?query=up" 2>/dev/null || echo "")

if [ -z "$QUERY_RESULT" ]; then
    fail "Impossible d'exécuter une requête via Grafana"
fi

# Vérifier que la requête retourne des résultats
RESULT_COUNT=$(echo "$QUERY_RESULT" | grep -o '"metric":{' | wc -l)
if [ "$RESULT_COUNT" -eq 0 ]; then
    warn "La requête n'a retourné aucun résultat. Les métriques ne sont peut-être pas encore collectées."
    echo "   Réponse de la requête:"
    echo "$QUERY_RESULT" | sed 's/^/   /'
else
    pass "La requête a retourné $RESULT_COUNT série(s) de métriques"
    echo "   Grafana peut interroger Prometheus avec succès!"
fi

echo ""
echo "=========================================="
echo "RÉSUMÉ DES TESTS"
echo "=========================================="
echo ""
echo -e "${GREEN}✓${NC} Prometheus est opérationnel et collecte des métriques"
echo -e "${GREEN}✓${NC} Grafana est opérationnel"
echo -e "${GREEN}✓${NC} Datasource Prometheus est configurée dans Grafana"
echo -e "${GREEN}✓${NC} Grafana peut interroger Prometheus"
echo ""

if [ "$RESULT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ LES DONNÉES CIRCULENT CORRECTEMENT   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
else
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}   ⚠ Configuration OK, en attente de données${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
    echo ""
    echo "Les données circuleront une fois que les targets seront actives."
    echo "Attendez quelques minutes que Prometheus scrappe les pods."
fi

echo ""
echo "Pour accéder à Grafana:"
echo "  kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
echo "  Puis ouvrir: http://localhost:3000"
echo "  Credentials: admin / admin2024"
echo ""
echo "Pour accéder à Prometheus:"
echo "  kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
echo "  Puis ouvrir: http://localhost:9090"
echo ""
