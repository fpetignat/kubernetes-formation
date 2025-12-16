# TP10 - Démarrage Rapide (Quick Start)

## 🚀 Déploiement en 3 minutes

### Prérequis
- Cluster Kubernetes fonctionnel (minikube ou kubeadm)
- kubectl configuré
- **Metrics Server installé** (pour HPA)

### Installation de Metrics Server (si nécessaire)

**Minikube :**
```bash
minikube addons enable metrics-server
```

**Kubeadm :**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Vérifier :
```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

### Déploiement automatique

```bash
cd tp10/

# Option 1 : Utiliser le script de déploiement
./deploy.sh

# Option 2 : Déploiement manuel étape par étape
kubectl create namespace taskflow

# PostgreSQL (avec initContainer qui crée 1000 tâches)
kubectl apply -f 01-postgres-init-script.yaml
kubectl apply -f 02-postgres-secret.yaml
kubectl apply -f 03-postgres-pvc.yaml
kubectl apply -f 04-postgres-deployment.yaml
kubectl apply -f 05-postgres-service.yaml

# Redis
kubectl apply -f 06-redis-deployment.yaml
kubectl apply -f 07-redis-service.yaml

# Backend API (avec HPA)
kubectl apply -f 08-backend-config.yaml
kubectl apply -f 09-backend-app-code.yaml
kubectl apply -f 09-backend-deployment.yaml
kubectl apply -f 10-backend-service.yaml
kubectl apply -f 11-backend-hpa.yaml

# Frontend
kubectl apply -f 12-frontend-config.yaml
kubectl apply -f 13-frontend-deployment.yaml
kubectl apply -f 14-frontend-service.yaml

# Monitoring (Prometheus + Grafana)
kubectl apply -f 15-prometheus-config.yaml
kubectl apply -f 16-prometheus-rbac.yaml
kubectl apply -f 17-prometheus-pvc.yaml
kubectl apply -f 18-prometheus-deployment.yaml
kubectl apply -f 19-prometheus-service.yaml
kubectl apply -f 20-grafana-deployment.yaml
kubectl apply -f 21-grafana-service.yaml
```

### Vérification

```bash
# Voir l'état de tous les composants
kubectl get all -n taskflow

# Vérifier que PostgreSQL contient 1000 tâches
kubectl exec -n taskflow deployment/postgres -- psql -U taskflow -d taskflow_db -c "SELECT COUNT(*) FROM tasks;"

# Voir le HPA
kubectl get hpa -n taskflow
```

### Accès aux interfaces

**Frontend (application web) :**
```bash
# Minikube
minikube service frontend -n taskflow

# Kubeadm (obtenir l'URL)
kubectl get svc frontend -n taskflow
```

**Grafana (monitoring) :**
```bash
# Minikube
minikube service grafana -n taskflow

# Kubeadm
kubectl get svc grafana -n taskflow
```
- Username: `admin`
- Password: `admin2024`

### Test de l'auto-scaling

```bash
# Lancer le générateur de charge (5 pods qui bombardent l'API)
kubectl apply -f 22-load-generator.yaml

# Observer l'autoscaling en temps réel (2 terminaux)
# Terminal 1 : HPA
watch kubectl get hpa -n taskflow

# Terminal 2 : Pods
watch kubectl get pods -n taskflow -l app=backend-api

# Terminal 3 : Métriques CPU/Mémoire
watch kubectl top pods -n taskflow -l app=backend-api
```

**Ce que vous devriez observer :**
1. L'utilisation CPU des pods backend monte de ~5% à 60-80%
2. Le HPA crée de nouveaux pods (de 2 à 8-10 pods)
3. Après 2-3 minutes, la charge se répartit
4. L'utilisation CPU se stabilise autour de 50%

**Arrêter la charge :**
```bash
kubectl delete job load-generator -n taskflow
```

Le HPA va progressivement descaler les pods (retour à 2 replicas en ~5 minutes).

### Test automatisé

```bash
# Exécuter le script de test complet
./test-tp10.sh
```

Le script vérifie :
- ✅ Tous les deployments sont prêts
- ✅ PostgreSQL contient 1000 tâches
- ✅ L'API Backend fonctionne
- ✅ Le HPA est configuré
- ✅ Redis répond
- ✅ Prometheus est déployé
- ✅ Metrics Server est actif

### Configuration Grafana

1. Se connecter à Grafana (admin/admin2024)
2. Ajouter Prometheus comme Data Source :
   - **URL :** `http://prometheus.taskflow.svc.cluster.local:9090`
   - Cliquer **Save & Test**
3. Créer un dashboard avec ces métriques :
   - `container_cpu_usage_seconds_total` : CPU usage
   - `container_memory_working_set_bytes` : Memory usage
   - `kube_deployment_status_replicas` : Nombre de replicas

### Nettoyage

```bash
# Supprimer tout le projet
kubectl delete namespace taskflow

# Ou supprimer uniquement le load generator
kubectl delete job load-generator -n taskflow
```

## 📊 Architecture déployée

```
Utilisateurs
    ↓
[Frontend LoadBalancer]
    ↓
[Backend API × 2-10] ← HPA (auto-scaling)
    ↓
[PostgreSQL] + [Redis] + [Prometheus]
    ↓
[PVC × 2] (persistance)
```

## 🎯 Objectifs pédagogiques couverts

- ✅ **initContainers** : PostgreSQL initialise 1000 tâches au démarrage
- ✅ **HPA** : Auto-scaling de 2 à 10 pods selon CPU/mémoire
- ✅ **LoadBalancer** : Exposition du frontend et Grafana
- ✅ **PVC** : Persistance pour PostgreSQL et Prometheus
- ✅ **ConfigMaps/Secrets** : Configuration externalisée
- ✅ **Monitoring** : Prometheus + Grafana en temps réel
- ✅ **RBAC** : ServiceAccount pour Prometheus
- ✅ **Load Testing** : Générateur de charge pour tester l'autoscaling

## 🐛 Troubleshooting

**Problème : PostgreSQL ne démarre pas**
```bash
kubectl logs -n taskflow deployment/postgres
kubectl describe pod -n taskflow -l app=postgres
```
→ Vérifier que la StorageClass `standard` existe

**Problème : HPA ne scale pas**
```bash
kubectl describe hpa backend-api-hpa -n taskflow
kubectl top pods -n taskflow
```
→ Vérifier que Metrics Server fonctionne

**Problème : Le backend ne se connecte pas à PostgreSQL**
```bash
kubectl logs -n taskflow -l app=backend-api
```
→ Vérifier que PostgreSQL est prêt et que le secret existe

**Problème : Pas assez de RAM**
```bash
kubectl top nodes
```
→ Le projet nécessite au minimum 4 Go de RAM disponibles

## 📚 Pour aller plus loin

- Modifier les seuils du HPA (CPU 30% au lieu de 50%)
- Ajouter des Network Policies (TP5, TP8)
- Implémenter un Ingress au lieu de LoadBalancer
- Créer un dashboard Grafana personnalisé
- Ajouter des alertes dans Prometheus
- Déployer sur un cluster multi-nœuds (TP9)

## 🎓 Ressources

- [README complet du TP10](README.md)
- [Documentation HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
