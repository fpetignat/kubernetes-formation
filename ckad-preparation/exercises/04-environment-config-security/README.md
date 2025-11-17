# Exercices - Application Environment, Configuration and Security (25%)

## Objectifs du domaine

- Découvrir et utiliser ConfigMaps et Secrets
- Comprendre et configurer SecurityContexts
- Définir les resource requirements et limits
- Comprendre les ServiceAccounts et RBAC basics

---

## Exercice 1 : ConfigMap depuis Literals

**Temps estimé : 5 minutes**

1. Créer un ConfigMap nommé `app-config` avec les données :
   - `DB_HOST=mysql`
   - `DB_PORT=3306`
   - `APP_MODE=production`

2. Créer un Pod `app` (image: `busybox`) qui :
   - Charge toutes les clés du ConfigMap comme variables d'environnement
   - Exécute : `sleep 3600`

3. Vérifier les variables avec `kubectl exec`.

<details>
<summary>💡 Indice</summary>

```bash
k create cm app-config --from-literal=DB_HOST=mysql --from-literal=DB_PORT=3306 --from-literal=APP_MODE=production
k run app --image=busybox $do -- sleep 3600 > pod.yaml
# Éditer pour ajouter envFrom
```
</details>

---

## Exercice 2 : ConfigMap depuis Fichier

**Temps estimé : 7 minutes**

1. Créer un fichier `app.properties` avec :
   ```
   server.port=8080
   server.host=0.0.0.0
   log.level=INFO
   ```

2. Créer un ConfigMap `app-properties` depuis ce fichier

3. Créer un Pod `config-file-pod` qui monte ce ConfigMap comme fichier dans `/config/app.properties`

<details>
<summary>💡 Indice</summary>

```bash
echo -e "server.port=8080\nserver.host=0.0.0.0\nlog.level=INFO" > app.properties
k create cm app-properties --from-file=app.properties
```

```yaml
volumes:
- name: config-volume
  configMap:
    name: app-properties
volumeMounts:
- name: config-volume
  mountPath: /config
```
</details>

---

## Exercice 3 : Secret Générique

**Temps estimé : 6 minutes**

1. Créer un Secret nommé `db-secret` avec :
   - `username=admin`
   - `password=SuperSecret123`

2. Créer un Pod `secure-app` qui :
   - Utilise ces valeurs comme variables d'environnement `DB_USER` et `DB_PASS`
   - Image: `nginx:alpine`

3. Vérifier que les valeurs sont bien chargées (mais ne pas les afficher en clair dans les logs!).

<details>
<summary>💡 Indice</summary>

```bash
k create secret generic db-secret --from-literal=username=admin --from-literal=password=SuperSecret123
```

```yaml
env:
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: username
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```
</details>

---

## Exercice 4 : Secret comme Volume

**Temps estimé : 7 minutes**

1. Créer un Secret `tls-secret` avec deux fichiers :
   - `tls.crt` : contenu fictif "CERTIFICATE DATA"
   - `tls.key` : contenu fictif "PRIVATE KEY DATA"

2. Créer un Pod `tls-app` qui monte ce Secret dans `/etc/tls/`

3. Vérifier que les fichiers sont présents avec `kubectl exec`.

<details>
<summary>💡 Indice</summary>

```bash
echo "CERTIFICATE DATA" > tls.crt
echo "PRIVATE KEY DATA" > tls.key
k create secret generic tls-secret --from-file=tls.crt --from-file=tls.key
```

```yaml
volumes:
- name: tls-volume
  secret:
    secretName: tls-secret
volumeMounts:
- name: tls-volume
  mountPath: /etc/tls
  readOnly: true
```
</details>

---

## Exercice 5 : Resource Requests et Limits

**Temps estimé : 6 minutes**

Créer un Pod nommé `resource-pod` qui :
- Utilise l'image `nginx:alpine`
- Requests :
  - CPU: 100m
  - Memory: 128Mi
- Limits :
  - CPU: 200m
  - Memory: 256Mi

Vérifier les ressources allouées avec `k describe pod`.

<details>
<summary>💡 Indice</summary>

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```
</details>

---

## Exercice 6 : ResourceQuota

**Temps estimé : 10 minutes**

1. Créer un namespace `quota-test`

2. Créer un ResourceQuota dans ce namespace avec :
   - Max 5 Pods
   - Total CPU requests: 2 cores
   - Total Memory requests: 2Gi

3. Créer un Pod qui respecte le quota

4. Essayer de créer trop de Pods et observer l'erreur

<details>
<summary>💡 Indice</summary>

```bash
k create ns quota-test
k create quota my-quota --hard=pods=5,requests.cpu=2,requests.memory=2Gi -n quota-test
```
</details>

---

## Exercice 7 : LimitRange

**Temps estimé : 8 minutes**

1. Créer un namespace `limit-test`

2. Créer un LimitRange qui impose :
   - Default requests : cpu=100m, memory=128Mi
   - Default limits : cpu=200m, memory=256Mi
   - Max : cpu=500m, memory=512Mi

3. Créer un Pod sans spécifier de ressources et vérifier que les valeurs par défaut sont appliquées

<details>
<summary>💡 Indice</summary>

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: limit-test
spec:
  limits:
  - default:
      memory: 256Mi
      cpu: 200m
    defaultRequest:
      memory: 128Mi
      cpu: 100m
    max:
      memory: 512Mi
      cpu: 500m
    type: Container
```
</details>

---

## Exercice 8 : SecurityContext - runAsUser

**Temps estimé : 7 minutes**

Créer un Pod nommé `secure-pod` qui :
- Utilise l'image `busybox`
- S'exécute en tant qu'utilisateur non-root (UID 1000)
- Groupe GID 3000
- Commande : `sleep 3600`

Vérifier l'UID avec `kubectl exec secure-pod -- id`.

<details>
<summary>💡 Indice</summary>

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 3000
```
</details>

---

## Exercice 9 : SecurityContext - Filesystem ReadOnly

**Temps estimé : 8 minutes**

Créer un Pod nommé `readonly-pod` qui :
- Utilise l'image `nginx:alpine`
- Le filesystem du container est en lecture seule (`readOnlyRootFilesystem: true`)
- Monte un volume `emptyDir` sur `/var/cache/nginx` (nginx a besoin d'écrire ici)
- Monte un volume `emptyDir` sur `/var/run` (nginx a besoin d'écrire ici aussi)

<details>
<summary>💡 Indice</summary>

```yaml
securityContext:
  readOnlyRootFilesystem: true
volumes:
- name: cache-volume
  emptyDir: {}
- name: run-volume
  emptyDir: {}
volumeMounts:
- name: cache-volume
  mountPath: /var/cache/nginx
- name: run-volume
  mountPath: /var/run
```
</details>

---

## Exercice 10 : SecurityContext - Capabilities

**Temps estimé : 9 minutes**

Créer un Pod nommé `cap-pod` qui :
- Utilise l'image `nginx:alpine`
- Drop toutes les capabilities par défaut
- Ajoute uniquement `NET_BIND_SERVICE` (pour bind sur ports < 1024)

<details>
<summary>💡 Indice</summary>

```yaml
securityContext:
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE
```
</details>

---

## Exercice 11 : ServiceAccount

**Temps estimé : 6 minutes**

1. Créer un ServiceAccount nommé `app-sa`

2. Créer un Pod `sa-pod` qui utilise ce ServiceAccount

3. Vérifier le ServiceAccount monté dans le Pod (`/var/run/secrets/kubernetes.io/serviceaccount/`)

<details>
<summary>💡 Indice</summary>

```bash
k create sa app-sa
```

```yaml
spec:
  serviceAccountName: app-sa
```

```bash
k exec sa-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```
</details>

---

## Exercice 12 : ConfigMap et Secret combinés

**Temps estimé : 10 minutes**

1. Créer un ConfigMap `app-env` avec :
   - `APP_NAME=MyApp`
   - `APP_VERSION=1.0.0`

2. Créer un Secret `app-creds` avec :
   - `api-key=secret123`

3. Créer un Pod `full-config` qui :
   - Charge le ConfigMap comme variables d'environnement
   - Monte le Secret comme fichier dans `/secrets/api-key`
   - Image: `busybox`, commande: `sleep 3600`

<details>
<summary>💡 Indice</summary>

```yaml
envFrom:
- configMapRef:
    name: app-env
volumes:
- name: secret-volume
  secret:
    secretName: app-creds
volumeMounts:
- name: secret-volume
  mountPath: /secrets
```
</details>

---

## Exercice 13 : SecurityContext au niveau Pod et Container

**Temps estimé : 10 minutes**

Créer un Pod nommé `multi-security` avec :
- SecurityContext au niveau Pod :
  - `fsGroup: 2000`
  - `runAsUser: 1000`
- Deux containers :
  - `nginx` (image: `nginx:alpine`) - utilise le security context du Pod
  - `busybox` (image: `busybox`) - override avec `runAsUser: 3000`

Vérifier les UIDs de chaque container.

<details>
<summary>💡 Indice</summary>

Le securityContext au niveau container override celui au niveau Pod.

```bash
k exec multi-security -c nginx -- id
k exec multi-security -c busybox -- id
```
</details>

---

## Exercice 14 : Immutable ConfigMap et Secret

**Temps estimé : 7 minutes**

1. Créer un ConfigMap `immutable-config` avec `immutable: true` et données `key=value`

2. Créer un Secret `immutable-secret` avec `immutable: true` et données `password=secret`

3. Essayer de modifier ces ressources et observer qu'elles sont protégées

<details>
<summary>💡 Indice</summary>

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
data:
  key: value
immutable: true
```

Tenter `k edit cm immutable-config` et modifier une valeur → erreur.
</details>

---

## Exercice 15 : Variables d'environnement avec FieldRef

**Temps estimé : 8 minutes**

Créer un Pod nommé `fieldref-pod` qui :
- Utilise l'image `busybox`
- A des variables d'environnement qui référencent :
  - `POD_NAME` : le nom du Pod
  - `POD_NAMESPACE` : le namespace
  - `POD_IP` : l'IP du Pod
  - `NODE_NAME` : le nom du node
- Commande : `sleep 3600`

Vérifier avec `kubectl exec`.

<details>
<summary>💡 Indice</summary>

```yaml
env:
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
```
</details>

---

## 🎯 Objectifs d'apprentissage

Après avoir complété ces exercices, vous devriez être capable de :

- ✅ Créer et utiliser ConfigMaps (literals, fichiers, répertoires)
- ✅ Créer et utiliser Secrets (generic, TLS, docker-registry)
- ✅ Monter ConfigMaps et Secrets comme volumes ou env vars
- ✅ Configurer resource requests et limits
- ✅ Créer et appliquer ResourceQuotas
- ✅ Créer et appliquer LimitRanges
- ✅ Configurer SecurityContext (runAsUser, fsGroup, readOnlyRootFilesystem)
- ✅ Gérer les capabilities Linux
- ✅ Créer et utiliser ServiceAccounts
- ✅ Utiliser fieldRef pour les métadonnées du Pod
- ✅ Comprendre les ConfigMaps et Secrets immutables

---

## 📚 Références

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)

---

**💡 Conseil** : Ce domaine vaut 25% de l'examen ! Maîtrisez ConfigMaps, Secrets, SecurityContext et Resources.
