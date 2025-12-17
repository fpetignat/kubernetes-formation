# Guide de Vérification des Métriques - TP10 TaskFlow

## 🎯 Objectif

Ce guide explique comment vérifier que les données circulent correctement entre **Prometheus** et **Grafana** dans le TP10 TaskFlow.

## 🔍 Problème identifié initialement

**Situation avant correction** :
- ✅ Prometheus collectait les métriques des pods (backend-api, postgres, redis)
- ✅ Service Prometheus accessible via DNS interne
- ❌ **Grafana n'avait AUCUNE datasource Prometheus configurée**

**Conséquence** : Les métriques ne circulaient pas car Grafana ne savait pas où les récupérer.

## ✅ Solution implémentée

### 1. Provisioning automatique de la datasource

**Fichier créé** : `20-grafana-datasource.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: taskflow
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus.taskflow.svc.cluster.local:9090
      isDefault: true
      editable: true
```

**Configuration** :
- **Datasource** : Prometheus
- **URL interne** : `http://prometheus.taskflow.svc.cluster.local:9090`
- **Access mode** : `proxy` (Grafana interroge Prometheus côté serveur)
- **isDefault** : `true` (datasource par défaut)
- **editable** : `true` (peut être modifiée dans l'UI Grafana)

### 2. Montage de la datasource dans le pod Grafana

**Fichier modifié** : `20-grafana-deployment.yaml`

Ajout du volume et volumeMount :
```yaml
volumeMounts:
  - name: grafana-datasources
    mountPath: /etc/grafana/provisioning/datasources
    readOnly: true

volumes:
  - name: grafana-datasources
    configMap:
      name: grafana-datasources
```

**Chemin de provisioning** : `/etc/grafana/provisioning/datasources/datasources.yaml`

Grafana détecte automatiquement ce fichier au démarrage et configure la datasource.

## 🧪 Tests de validation

### Test automatique complet

Un script de test automatisé a été créé : `test-metrics-flow.sh`

**Exécution** :
```bash
cd tp10/
./test-metrics-flow.sh
```

**Tests effectués par le script** :
1. ✅ Vérification des pods Prometheus et Grafana (Running)
2. ✅ Accessibilité de Prometheus (API `/api/v1/targets`)
3. ✅ Collecte de métriques par Prometheus
4. ✅ Accessibilité de Grafana (API `/api/health`)
5. ✅ Présence de la ConfigMap `grafana-datasources`
6. ✅ Montage du fichier datasource dans le pod Grafana
7. ✅ Configuration de la datasource Prometheus dans Grafana (via API)
8. ✅ Test de requête : Grafana peut interroger Prometheus

**Résultat attendu** :
```
═══════════════════════════════════════════
   ✓ LES DONNÉES CIRCULENT CORRECTEMENT
═══════════════════════════════════════════
```

### Tests manuels

#### 1. Vérifier que Prometheus collecte des métriques

**Port-forward vers Prometheus** :
```bash
kubectl port-forward -n taskflow svc/prometheus 9090:9090
```

**Ouvrir dans le navigateur** : http://localhost:9090

**Vérifications** :
- Aller dans **Status → Targets**
- Vérifier que les targets `kubernetes-pods` sont **UP** (vert)
- Au moins 3 targets doivent être actives : backend-api, postgres, redis

**Query test** :
- Aller dans **Graph**
- Exécuter la requête : `up{job="kubernetes-pods"}`
- Résultat attendu : Liste des pods avec `value=1` (up)

#### 2. Vérifier la datasource dans Grafana

**Port-forward vers Grafana** :
```bash
kubectl port-forward -n taskflow svc/grafana 3000:3000
```

**Ouvrir dans le navigateur** : http://localhost:3000

**Credentials** : `admin` / `admin2024`

**Vérifications** :
1. Aller dans **Configuration → Data Sources** (⚙️ → Data Sources)
2. Vérifier qu'une datasource **Prometheus** existe
3. Cliquer sur la datasource Prometheus
4. Vérifier l'URL : `http://prometheus.taskflow.svc.cluster.local:9090`
5. Cliquer sur **Save & Test**
6. Résultat attendu : ✅ **"Data source is working"**

#### 3. Créer un dashboard de test

**Dans Grafana** :
1. Cliquer sur **+ → Dashboard → Add new panel**
2. Dans **Query**, sélectionner **Prometheus** (datasource)
3. Requête de test : `up{job="kubernetes-pods"}`
4. Cliquer sur **Run queries**
5. Résultat attendu : Graphique avec 3 séries (backend-api, postgres, redis)

**Autres requêtes utiles** :
```promql
# Nombre de tâches dans PostgreSQL
pg_stat_database_numbackends

# Utilisation CPU des conteneurs
rate(container_cpu_usage_seconds_total[5m])

# Utilisation mémoire
container_memory_usage_bytes

# Requêtes HTTP vers le backend
http_requests_total

# Pods disponibles
up{job="kubernetes-pods"}
```

## 🔧 Déploiement et redéploiement

### Déploiement initial complet

Si vous déployez le TP10 pour la première fois avec la correction :

```bash
cd tp10/
./deploy.sh
```

Le script `deploy.sh` déploie tous les composants dans le bon ordre, incluant la nouvelle ConfigMap datasource.

### Mise à jour d'un déploiement existant

Si vous avez déjà déployé le TP10 **sans** la datasource automatique, appliquez les changements :

```bash
# 1. Créer la ConfigMap datasource
kubectl apply -f 20-grafana-datasource.yaml

# 2. Mettre à jour le deployment Grafana (pour monter la datasource)
kubectl apply -f 20-grafana-deployment.yaml

# 3. Attendre que le pod Grafana redémarre
kubectl wait --for=condition=Ready pod -l app=grafana -n taskflow --timeout=120s

# 4. Vérifier que la datasource est configurée
kubectl exec -n taskflow $(kubectl get pod -n taskflow -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
  ls /etc/grafana/provisioning/datasources/datasources.yaml

# 5. Tester la circulation des métriques
./test-metrics-flow.sh
```

## 🐛 Troubleshooting

### Problème : Datasource Prometheus introuvable dans Grafana

**Symptôme** : Dans Grafana, aucune datasource Prometheus n'apparaît.

**Solutions** :
1. Vérifier que la ConfigMap existe :
   ```bash
   kubectl get configmap grafana-datasources -n taskflow
   ```

2. Vérifier que le fichier est monté dans le pod :
   ```bash
   kubectl exec -n taskflow $(kubectl get pod -n taskflow -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
     cat /etc/grafana/provisioning/datasources/datasources.yaml
   ```

3. Vérifier les logs Grafana pour erreurs de provisioning :
   ```bash
   kubectl logs -n taskflow $(kubectl get pod -n taskflow -l app=grafana -o jsonpath='{.items[0].metadata.name}') | grep -i "datasource"
   ```

4. Redémarrer le pod Grafana :
   ```bash
   kubectl delete pod -n taskflow -l app=grafana
   kubectl wait --for=condition=Ready pod -l app=grafana -n taskflow --timeout=120s
   ```

### Problème : "Data source is working" mais pas de données

**Symptôme** : Le test de datasource réussit, mais les requêtes ne retournent rien.

**Solutions** :
1. Vérifier que Prometheus collecte des métriques :
   ```bash
   kubectl port-forward -n taskflow svc/prometheus 9090:9090
   # Ouvrir http://localhost:9090 et vérifier Status → Targets
   ```

2. Vérifier les targets Prometheus :
   ```bash
   kubectl exec -n taskflow $(kubectl get pod -n taskflow -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -- \
     wget -q -O - http://localhost:9090/api/v1/targets | grep "health"
   ```

3. Attendre quelques minutes : Prometheus scrappe les métriques toutes les 15 secondes (`scrape_interval: 15s`). Il faut attendre au moins 30-60 secondes après le démarrage pour voir les premières métriques.

### Problème : Targets Prometheus en état "Down"

**Symptôme** : Dans Prometheus (Status → Targets), les targets sont en rouge avec état "Down".

**Causes possibles** :
1. **RBAC insuffisant** : Le ServiceAccount Prometheus n'a pas les permissions pour découvrir les pods.
   ```bash
   kubectl get clusterrolebinding prometheus -n taskflow -o yaml
   ```

2. **Pods pas encore prêts** : Les pods backend-api, postgres, redis ne sont pas Running.
   ```bash
   kubectl get pods -n taskflow
   ```

3. **Labels incorrects** : Les pods n'ont pas le label `app` attendu.
   ```bash
   kubectl get pods -n taskflow --show-labels | grep -E "(backend-api|postgres|redis)"
   ```

**Solutions** :
- Vérifier que tous les pods sont Running : `kubectl get pods -n taskflow`
- Vérifier les permissions RBAC : `kubectl apply -f 16-prometheus-rbac.yaml`
- Attendre 1-2 minutes que Prometheus détecte les targets

### Problème : Connexion refusée entre Grafana et Prometheus

**Symptôme** : Erreur "Connection refused" ou "Could not reach Prometheus".

**Solutions** :
1. Vérifier que le Service Prometheus existe :
   ```bash
   kubectl get svc prometheus -n taskflow
   ```

2. Tester la résolution DNS depuis le pod Grafana :
   ```bash
   kubectl exec -n taskflow $(kubectl get pod -n taskflow -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
     nslookup prometheus.taskflow.svc.cluster.local
   ```

3. Tester la connectivité HTTP depuis Grafana vers Prometheus :
   ```bash
   kubectl exec -n taskflow $(kubectl get pod -n taskflow -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
     wget -q -O - http://prometheus.taskflow.svc.cluster.local:9090/api/v1/query?query=up
   ```

## 📊 Métriques disponibles

### Métriques Kubernetes (collectées automatiquement)

| Métrique | Description |
|----------|-------------|
| `up` | État du pod (1 = up, 0 = down) |
| `container_cpu_usage_seconds_total` | Utilisation CPU cumulée |
| `container_memory_usage_bytes` | Utilisation mémoire actuelle |
| `container_network_receive_bytes_total` | Octets réseau reçus |
| `container_network_transmit_bytes_total` | Octets réseau transmis |

### Métriques applicatives (à implémenter)

Si vous voulez des métriques custom pour l'application backend-api, il faut instrumenter le code Python Flask avec `prometheus_client` :

```python
from prometheus_client import Counter, Histogram, generate_latest

# Définir des métriques
http_requests_total = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('request_duration_seconds', 'HTTP request duration')

# Dans les routes Flask
@app.route('/tasks')
@request_duration.time()
def get_tasks():
    http_requests_total.labels(method='GET', endpoint='/tasks', status=200).inc()
    # ... logique métier

# Endpoint /metrics pour Prometheus
@app.route('/metrics')
def metrics():
    return generate_latest()
```

## 🎓 Concepts clés

### Service Discovery Kubernetes

Prometheus utilise le **Kubernetes Service Discovery** pour détecter automatiquement les pods à scraper.

**Configuration** (dans `15-prometheus-config.yaml`) :
```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
      namespaces:
        names:
        - taskflow
    relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app]
      action: keep
      regex: backend-api|postgres|redis
```

**Fonctionnement** :
1. Prometheus interroge l'API Kubernetes pour lister les pods du namespace `taskflow`
2. Il filtre les pods avec le label `app` matching `backend-api|postgres|redis`
3. Il extrait les métadonnées (nom du pod, labels) pour les targets
4. Il scrappe l'endpoint `/metrics` de chaque pod toutes les 15 secondes

### Provisioning Grafana

Grafana supporte le **provisioning automatique** via des fichiers YAML.

**Avantages** :
- ✅ Configuration as Code (Infrastructure as Code)
- ✅ Pas besoin de configurer manuellement dans l'UI
- ✅ Reproductible et versionnable
- ✅ Idempotent (redémarrage sans perte de config)

**Types de provisioning** :
- **Datasources** : `/etc/grafana/provisioning/datasources/*.yaml`
- **Dashboards** : `/etc/grafana/provisioning/dashboards/*.yaml`
- **Notifiers** : `/etc/grafana/provisioning/notifiers/*.yaml`

### Access mode : Proxy vs Direct

**Proxy mode** (utilisé ici) :
- Grafana serveur interroge Prometheus côté backend
- URL interne Kubernetes : `http://prometheus.taskflow.svc.cluster.local:9090`
- Avantages : Pas besoin d'exposer Prometheus publiquement, plus sécurisé

**Direct mode** (alternative) :
- Le navigateur client interroge Prometheus directement
- Nécessite d'exposer Prometheus via LoadBalancer/Ingress
- Avantages : Moins de charge sur Grafana serveur

## 🔗 Ressources

### Documentation officielle
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Prometheus Kubernetes SD](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
- [Grafana Provisioning Datasources](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources)
- [Grafana Data Source API](https://grafana.com/docs/grafana/latest/developers/http_api/data_source/)

### Dashboards Grafana utiles
- [Kubernetes Cluster Monitoring](https://grafana.com/grafana/dashboards/7249)
- [Kubernetes Pod Monitoring](https://grafana.com/grafana/dashboards/6417)
- [Node Exporter Full](https://grafana.com/grafana/dashboards/1860)

### PromQL (Prometheus Query Language)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- [PromQL Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

## ✅ Checklist de vérification

Avant de considérer que les métriques circulent correctement, vérifiez :

- [ ] Pod Prometheus est Running
- [ ] Pod Grafana est Running
- [ ] ConfigMap `grafana-datasources` existe
- [ ] Fichier datasource monté dans `/etc/grafana/provisioning/datasources/`
- [ ] Service Prometheus accessible (ClusterIP sur port 9090)
- [ ] Prometheus a au moins 1 target UP (Status → Targets)
- [ ] Grafana liste la datasource Prometheus (Configuration → Data Sources)
- [ ] Test de datasource réussit : "Data source is working" ✅
- [ ] Requête `up{job="kubernetes-pods"}` retourne des résultats
- [ ] Script `./test-metrics-flow.sh` passe tous les tests

**Résultat attendu** :
```
═══════════════════════════════════════════
   ✓ LES DONNÉES CIRCULENT CORRECTEMENT
═══════════════════════════════════════════
```

---

**Dernière mise à jour** : 2025-12-17
**Version** : 1.0
**Auteur** : Claude (correction automatisation Prometheus → Grafana)
