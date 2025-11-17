# Solutions - Practice Exam CKAD Session 01

## Question 1 (4%) - Pod Multi-Container

### Solution

```bash
k run log-processor --image=nginx:alpine $do > q1.yaml
vim q1.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: log-processor
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: logs
      mountPath: /var/log
  - name: logger
    image: busybox
    command: ['/bin/sh', '-c', 'while true; do date >> /var/log/app.log; sleep 5; done']
    volumeMounts:
    - name: logs
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}
```

### Vérification

```bash
k apply -f q1.yaml
k logs log-processor -c logger
k exec log-processor -c app -- tail /var/log/app.log
```

---

## Question 2 (7%) - Deployment et Service

### Solution

```bash
# Context et namespace
k config use-context main
k create ns production

# Deployment
k create deploy web-app -n production \
  --image=nginx:1.21 \
  --replicas=4

k label deploy web-app -n production app=web tier=frontend env=production

# Service
k expose deploy web-app -n production \
  --name=web-svc \
  --port=80 \
  --type=NodePort

# Fixer le NodePort à 30080
k edit svc web-svc -n production
# Ou avec patch:
k patch svc web-svc -n production -p '{"spec":{"ports":[{"port":80,"nodePort":30080}]}}'
```

### Vérification

```bash
k get deploy web-app -n production
k get svc web-svc -n production
k get endpoints web-svc -n production
# Devrait montrer 4 endpoints
```

---

## Question 3 (3%) - ConfigMap

### Solution

```bash
k create cm app-config \
  --from-literal=DATABASE_URL=postgresql://db.example.com:5432/mydb \
  --from-literal=CACHE_ENABLED=true \
  --from-literal=LOG_LEVEL=info

k run config-test --image=busybox $do -- sleep 3600 > q3.yaml
vim q3.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-test
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-config
```

### Vérification

```bash
k apply -f q3.yaml
k exec config-test -- env | grep -E 'DATABASE_URL|CACHE_ENABLED|LOG_LEVEL'
```

---

## Question 4 (8%) - Health Checks

### Solution

```bash
k create deploy api-server --image=nginx:alpine --replicas=3 $do > q4.yaml
vim q4.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
```

### Vérification

```bash
k apply -f q4.yaml
k get deploy api-server
k describe pod -l app=api-server | grep -A 10 "Liveness:\|Readiness:"
```

---

## Question 5 (5%) - Secret et Volume

### Solution

```bash
k create ns secure
k create secret generic db-credentials -n secure \
  --from-literal=username=admin \
  --from-literal=password='P@ssw0rd123!'

k run secure-app -n secure --image=nginx:alpine $do > q5.yaml
vim q5.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: secure
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
```

### Vérification

```bash
k apply -f q5.yaml
k exec secure-app -n secure -- ls -la /etc/secrets
k exec secure-app -n secure -- cat /etc/secrets/username
```

---

## Question 6 (7%) - NetworkPolicy

### Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: restricted
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Vérification

```bash
k apply -f q6.yaml -n restricted
k describe networkpolicy backend-policy -n restricted

# Test: Créer un Pod frontend et tester l'accès
k run frontend -n restricted --image=busybox --labels="app=frontend" -- sleep 3600
BACKEND_IP=$(k get pod -n restricted -l app=backend -o jsonpath='{.items[0].status.podIP}')
k exec frontend -n restricted -- wget --timeout=2 http://$BACKEND_IP:8080
# Devrait marcher

# Test: Depuis autre Pod (devrait échouer)
k run other -n restricted --image=busybox -- sleep 3600
k exec other -n restricted -- wget --timeout=2 http://$BACKEND_IP:8080
# Devrait timeout
```

---

## Question 7 (2%) - Scaling

### Solution

```bash
k config use-context main
k scale deploy web-app -n production --replicas=6
```

### Vérification

```bash
k get deploy web-app -n production
k get pods -n production -l app=web-app
# Devrait montrer 6 Pods Running
```

---

## Question 8 (6%) - Rolling Update et Rollback

### Solution

```bash
k config use-context main

# 1. Update avec --record
k set image deploy/web-app -n production nginx=nginx:1.22 --record

# 2. Historique
k rollout history deploy/web-app -n production

# 3. Rollback
k rollout undo deploy/web-app -n production

# 4. Vérifier l'image
k describe deploy web-app -n production | grep Image
# Devrait afficher nginx:1.21
```

---

## Question 9 (5%) - Job

### Solution

```bash
k create ns batch
k create job data-import -n batch --image=busybox $do -- sh -c "echo 'Processing data...' && sleep 10 && echo 'Done'" > q9.yaml
vim q9.yaml
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-import
  namespace: batch
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 4
  template:
    spec:
      containers:
      - name: busybox
        image: busybox
        command: ["sh", "-c", "echo 'Processing data...' && sleep 10 && echo 'Done'"]
      restartPolicy: Never
```

### Vérification

```bash
k apply -f q9.yaml
k get jobs -n batch -w
k get pods -n batch
```

---

## Question 10 (8%) - Resource Limits et LimitRange

### Solution

```bash
k create ns limited
```

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: limited
spec:
  limits:
  - default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 500m
      memory: 512Mi
    type: Container
```

```bash
k apply -f limitrange.yaml

# Pod sans ressources
k run resource-test -n limited --image=nginx:alpine
```

### Vérification

```bash
k describe pod resource-test -n limited | grep -A 10 "Requests:\|Limits:"
# Devrait afficher les limites par défaut
```

---

## Question 11 (6%) - Ingress

### Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: web
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1-svc
            port:
              number: 80
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2-svc
            port:
              number: 80
```

### Vérification

```bash
k apply -f q11.yaml -n web
k get ingress web-ingress -n web
k describe ingress web-ingress -n web
```

---

## Question 12 (4%) - CronJob

### Solution

```bash
k create cronjob backup --image=busybox --schedule="0 2 * * *" $do -- sh -c 'echo "Backup started at $(date)"' > q12.yaml
vim q12.yaml
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 2 * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox
            command: ["/bin/sh", "-c", "echo \"Backup started at $(date)\""]
          restartPolicy: OnFailure
```

### Vérification

```bash
k apply -f q12.yaml
k get cronjobs
k describe cronjob backup
```

---

## Question 13 (7%) - SecurityContext

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-app
  namespace: secure
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

### Vérification

```bash
k apply -f q13.yaml -n secure
k exec hardened-app -n secure -- id
k exec hardened-app -n secure -- touch /test.txt
# Devrait échouer (read-only)
k exec hardened-app -n secure -- touch /var/cache/nginx/test.txt
# Devrait marcher
```

---

## Question 14 (3%) - Labels et Selectors

### Solution

```bash
# 1. Ajouter label version=v2 aux Pods app=web
k label pods -l app=web version=v2

# 2. Lister Pods avec env=production ET tier=frontend
k get pods -l 'env=production,tier=frontend'

# 3. Supprimer label temporary de tous les Pods
k label pods --all temporary-
```

---

## Question 15 (8%) - Init Container et ServiceAccount

### Solution

```bash
# ServiceAccount
k create sa app-sa

# Pod
k run init-demo --image=nginx:alpine $do > q15.yaml
vim q15.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  serviceAccountName: app-sa
  initContainers:
  - name: init-wait
    image: busybox
    command: ["sleep", "10"]
  containers:
  - name: nginx
    image: nginx:alpine
```

### Vérification

```bash
k apply -f q15.yaml
k get pods init-demo -w
# Observer: Init:0/1, puis Running après 10 secondes
k describe pod init-demo
```

---

## Question 16 (6%) - Debugging

### Étapes de debug

```bash
k config use-context main

# 1. Voir l'état du Pod
k get pod broken-app -n troubleshoot

# 2. Describe pour identifier le problème
k describe pod broken-app -n troubleshoot

# 3. Voir les logs
k logs broken-app -n troubleshoot
k logs broken-app -n troubleshoot --previous

# 4. Obtenir le YAML
k get pod broken-app -n troubleshoot -o yaml > fix.yaml
```

### Problèmes courants et solutions

**Cas 1: Image inexistante**
```yaml
# Changer:
image: nginx:doesnotexist
# En:
image: nginx:alpine
```

**Cas 2: CrashLoopBackOff**
```yaml
# Changer la commande qui crash
command: ["exit", "1"]
# En:
command: ["sleep", "3600"]
```

**Cas 3: Ressources insuffisantes**
```yaml
# Réduire les ressources demandées
resources:
  requests:
    memory: "10Gi"  # Trop élevé
# En:
  requests:
    memory: "128Mi"
```

### Correction

```bash
vim fix.yaml
# Corriger le problème identifié
k delete pod broken-app -n troubleshoot
k apply -f fix.yaml -n troubleshoot

# Ou replace --force
k replace -f fix.yaml --force
```

---

## Question 17 (7%) - Persistent Storage

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
  namespace: data
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: data-volume
      mountPath: /data
    livenessProbe:
      exec:
        command:
        - test
        - -f
        - /data/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
  volumes:
  - name: data-volume
    emptyDir: {}
```

### Créer le fichier healthy

```bash
k apply -f q17.yaml -n data

# Attendre que le Pod démarre
k wait --for=condition=Ready pod/data-pod -n data --timeout=30s || true

# Créer le fichier
k exec data-pod -n data -- touch /data/healthy

# Vérifier
k get pod data-pod -n data
# Devrait être Running
```

---

## 📊 Grille de notation

| Question | Points | Temps cible | Difficulté |
|----------|--------|-------------|------------|
| Q1  | 4  | 6 min  | Facile |
| Q2  | 7  | 8 min  | Moyen |
| Q3  | 3  | 4 min  | Facile |
| Q4  | 8  | 10 min | Moyen |
| Q5  | 5  | 6 min  | Facile |
| Q6  | 7  | 10 min | Difficile |
| Q7  | 2  | 2 min  | Facile |
| Q8  | 6  | 6 min  | Moyen |
| Q9  | 5  | 7 min  | Moyen |
| Q10 | 8  | 10 min | Difficile |
| Q11 | 6  | 8 min  | Moyen |
| Q12 | 4  | 5 min  | Facile |
| Q13 | 7  | 10 min | Difficile |
| Q14 | 3  | 4 min  | Facile |
| Q15 | 8  | 8 min  | Moyen |
| Q16 | 6  | 10 min | Difficile |
| Q17 | 7  | 8 min  | Moyen |

**Total : 100 points en ~122 minutes**

---

## 💡 Stratégie optimale

### Ordre suggéré (par ROI = points/minute)

1. **Q7** (2pts, 2min) = 1.0 pts/min
2. **Q14** (3pts, 4min) = 0.75 pts/min
3. **Q3** (3pts, 4min) = 0.75 pts/min
4. **Q12** (4pts, 5min) = 0.8 pts/min
5. **Q1** (4pts, 6min) = 0.67 pts/min
6. **Q5** (5pts, 6min) = 0.83 pts/min
7. **Q8** (6pts, 6min) = 1.0 pts/min
8. **Q9** (5pts, 7min) = 0.71 pts/min
9. **Q11** (6pts, 8min) = 0.75 pts/min
10. **Q15** (8pts, 8min) = 1.0 pts/min
11. **Q17** (7pts, 8min) = 0.875 pts/min
12. **Q2** (7pts, 8min) = 0.875 pts/min
13. **Q4** (8pts, 10min) = 0.8 pts/min
14. **Q6** (7pts, 10min) = 0.7 pts/min
15. **Q10** (8pts, 10min) = 0.8 pts/min
16. **Q13** (7pts, 10min) = 0.7 pts/min
17. **Q16** (6pts, 10min) = 0.6 pts/min

### Tips

- Faire les quick wins d'abord (Q7, Q14, Q3, Q12)
- Garder 20 min pour réviser
- Marquer les difficiles et y revenir

---

## 🎯 Checklist de révision

Après l'examen, vérifier :

- [ ] Tous les contextes et namespaces corrects
- [ ] Tous les Pods sont Running
- [ ] Tous les Services ont des endpoints
- [ ] Les Deployments ont le bon nombre de replicas
- [ ] Les probes sont correctement configurées
- [ ] Les NetworkPolicies bloquent/autorisent correctement
- [ ] Les ressources sont dans les limites
- [ ] Les Secrets/ConfigMaps sont montés
