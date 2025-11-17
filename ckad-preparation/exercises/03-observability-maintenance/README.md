# Exercices - Application Observability and Maintenance (15%)

## Objectifs du domaine

- Comprendre et implémenter les probes (liveness, readiness, startup)
- Surveiller, logger et déboguer les applications Kubernetes
- Utiliser les métriques pour le monitoring

---

## Exercice 1 : Liveness Probe HTTP

**Temps estimé : 7 minutes**

Créer un Pod nommé `liveness-http` qui :
- Utilise l'image `nginx:alpine`
- A une liveness probe HTTP GET sur le chemin `/` au port 80
- `initialDelaySeconds: 3`
- `periodSeconds: 3`

Vérifier que le Pod reste en état Running.

<details>
<summary>💡 Indice</summary>

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 3
  periodSeconds: 3
```
</details>

---

## Exercice 2 : Readiness Probe

**Temps estimé : 8 minutes**

Créer un Deployment `webapp-ready` avec :
- Image: `nginx:alpine`
- 3 replicas
- Readiness probe HTTP GET sur `/` au port 80
  - `initialDelaySeconds: 5`
  - `periodSeconds: 5`

Créer un Service ClusterIP qui expose ce Deployment sur le port 80.

Vérifier que les endpoints du Service ne contiennent que les Pods ready.

<details>
<summary>💡 Indice</summary>

```bash
k get endpoints webapp-ready
k describe svc webapp-ready
```
</details>

---

## Exercice 3 : Liveness Probe Exec

**Temps estimé : 6 minutes**

Créer un Pod nommé `liveness-exec` qui :
- Utilise l'image `busybox`
- Commande : `sh -c "touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600"`
- Liveness probe qui exécute : `cat /tmp/healthy`
  - `initialDelaySeconds: 5`
  - `periodSeconds: 5`

Observer que le Pod redémarre après ~30 secondes (quand le fichier est supprimé).

<details>
<summary>💡 Indice</summary>

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

Utilisez `k get pods -w` pour observer le redémarrage.
</details>

---

## Exercice 4 : Liveness et Readiness combinées

**Temps estimé : 10 minutes**

Créer un Pod nommé `probes-combined` qui :
- Utilise l'image `nginx:alpine`
- Liveness probe TCP sur port 80
  - `initialDelaySeconds: 10`
  - `periodSeconds: 5`
- Readiness probe HTTP GET sur `/` au port 80
  - `initialDelaySeconds: 5`
  - `periodSeconds: 3`

<details>
<summary>💡 Indice</summary>

```yaml
livenessProbe:
  tcpSocket:
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 5
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 3
```
</details>

---

## Exercice 5 : Startup Probe

**Temps estimé : 8 minutes**

Créer un Pod nommé `slow-start` qui :
- Utilise l'image `nginx:alpine`
- Startup probe HTTP GET sur `/` au port 80
  - `failureThreshold: 30`
  - `periodSeconds: 10`
- Liveness probe HTTP GET sur `/` au port 80
  - `periodSeconds: 5`

La startup probe donne jusqu'à 300 secondes (30 * 10) pour que l'app démarre avant que la liveness probe prenne le relais.

<details>
<summary>💡 Indice</summary>

```yaml
startupProbe:
  httpGet:
    path: /
    port: 80
  failureThreshold: 30
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /
    port: 80
  periodSeconds: 5
```
</details>

---

## Exercice 6 : Debugging - Pod CrashLoopBackOff

**Temps estimé : 10 minutes**

Créer un Pod nommé `crasher` qui :
- Utilise l'image `busybox`
- Commande : `sh -c "echo Starting...; exit 1"`

Le Pod va crasher immédiatement. Votre mission :
1. Identifier pourquoi le Pod crash
2. Consulter les logs
3. Corriger le problème (changer la commande en `sleep 3600`)

<details>
<summary>💡 Indice</summary>

```bash
k describe pod crasher
k logs crasher
k logs crasher --previous
k get pod crasher -o yaml > fix.yaml
# Éditer fix.yaml, changer la commande
k replace -f fix.yaml --force
```
</details>

---

## Exercice 7 : Logs Multi-Container

**Temps estimé : 8 minutes**

Créer un Pod nommé `multi-log` avec deux containers :
- Container `app` (image: `busybox`) : `sh -c "while true; do echo 'App log'; sleep 5; done"`
- Container `sidecar` (image: `busybox`) : `sh -c "while true; do echo 'Sidecar log'; sleep 3; done"`

Consulter les logs de chaque container séparément.

<details>
<summary>💡 Indice</summary>

```bash
k logs multi-log -c app
k logs multi-log -c sidecar
k logs multi-log --all-containers
```
</details>

---

## Exercice 8 : Events Debugging

**Temps estimé : 7 minutes**

Créer un Pod nommé `bad-image` qui utilise une image inexistante `nginx:doesnotexist`.

Le Pod va échouer. Utiliser les events pour identifier le problème :
1. Consulter les events du Pod
2. Consulter tous les events du namespace
3. Filtrer les events de type Warning

<details>
<summary>💡 Indice</summary>

```bash
k describe pod bad-image | grep -A 10 Events
k get events --sort-by=.metadata.creationTimestamp
k get events --field-selector type=Warning
```
</details>

---

## Exercice 9 : Exec pour Debugging

**Temps estimé : 6 minutes**

Créer un Pod nommé `debug-pod` avec l'image `nginx:alpine`.

Utiliser `kubectl exec` pour :
1. Vérifier le contenu de `/etc/nginx/nginx.conf`
2. Lister les processus en cours d'exécution
3. Vérifier les variables d'environnement
4. Tester la connectivité réseau avec `wget` ou `curl`

<details>
<summary>💡 Indice</summary>

```bash
k exec debug-pod -- cat /etc/nginx/nginx.conf
k exec debug-pod -- ps aux
k exec debug-pod -- env
k exec debug-pod -- wget -O- http://kubernetes.default.svc.cluster.local
```
</details>

---

## Exercice 10 : Port-Forward pour Testing

**Temps estimé : 5 minutes**

Créer un Deployment `test-app` avec l'image `nginx:alpine` et 2 replicas.

Utiliser `kubectl port-forward` pour :
1. Accéder à un Pod spécifique sur votre machine locale (port 8080 → 80)
2. Tester l'accès avec curl ou navigateur

<details>
<summary>💡 Indice</summary>

```bash
k port-forward pod/<pod-name> 8080:80
# Dans un autre terminal
curl http://localhost:8080
```
</details>

---

## Exercice 11 : Probe avec Custom Headers

**Temps estimé : 8 minutes**

Créer un Pod nommé `custom-probe` qui :
- Utilise l'image `nginx:alpine`
- Readiness probe HTTP GET avec :
  - Path: `/health`
  - Port: 80
  - HTTP Header: `X-Custom-Header: HealthCheck`
  - `initialDelaySeconds: 5`
  - `periodSeconds: 10`

<details>
<summary>💡 Indice</summary>

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 80
    httpHeaders:
    - name: X-Custom-Header
      value: HealthCheck
  initialDelaySeconds: 5
  periodSeconds: 10
```
</details>

---

## Exercice 12 : Failure Threshold et Success Threshold

**Temps estimé : 10 minutes**

Créer un Pod nommé `threshold-test` qui :
- Utilise l'image `nginx:alpine`
- Readiness probe HTTP GET sur `/` au port 80
  - `initialDelaySeconds: 5`
  - `periodSeconds: 3`
  - `failureThreshold: 3` (considéré not ready après 3 échecs consécutifs)
  - `successThreshold: 2` (considéré ready après 2 succès consécutifs)

Comprendre comment ces seuils affectent le statut du Pod.

<details>
<summary>💡 Indice</summary>

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 3
  failureThreshold: 3
  successThreshold: 2
```

`successThreshold` ne peut être > 1 que pour readiness probe.
</details>

---

## Exercice 13 : Monitoring avec kubectl top

**Temps estimé : 5 minutes**

Créer un Deployment `resource-hog` avec :
- Image: `nginx:alpine`
- 3 replicas
- Requests : cpu=100m, memory=128Mi
- Limits : cpu=200m, memory=256Mi

Utiliser `kubectl top` pour consulter l'utilisation des ressources :
1. Par node
2. Par pod
3. Par container

<details>
<summary>💡 Indice</summary>

```bash
k top nodes
k top pods
k top pods --containers
k top pods -l app=resource-hog
```

Note: Metrics Server doit être installé dans le cluster.
</details>

---

## 🎯 Objectifs d'apprentissage

Après avoir complété ces exercices, vous devriez être capable de :

- ✅ Configurer des liveness probes (HTTP, exec, TCP)
- ✅ Configurer des readiness probes
- ✅ Utiliser des startup probes pour les applications à démarrage lent
- ✅ Comprendre les différences entre les trois types de probes
- ✅ Déboguer des Pods en CrashLoopBackOff
- ✅ Consulter les logs (y compris multi-container)
- ✅ Utiliser les events pour identifier les problèmes
- ✅ Utiliser kubectl exec pour déboguer
- ✅ Utiliser port-forward pour tester localement
- ✅ Configurer des seuils (failureThreshold, successThreshold)
- ✅ Monitorer les ressources avec kubectl top

---

## 📚 Références

- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
- [Monitoring](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/)

---

**💡 Conseil** : Le debugging est crucial à l'examen. Maîtrisez `describe`, `logs`, `exec`, et `events` !
