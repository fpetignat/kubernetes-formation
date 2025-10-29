# TP3 - Persistance des données dans Kubernetes

## Objectifs du TP

À la fin de ce TP, vous serez capable de :
- Comprendre les différents types de volumes Kubernetes
- Créer et gérer des PersistentVolumes (PV) et PersistentVolumeClaims (PVC)
- Utiliser les StorageClasses pour le provisionnement dynamique
- Déployer une base de données avec persistance des données
- Gérer le cycle de vie des volumes
- Appliquer les bonnes pratiques de gestion du stockage

## Prérequis

- Avoir complété le TP1 et TP2
- Un cluster minikube fonctionnel
- Connaissance de base des manifests YAML

## Partie 1 : Introduction aux volumes Kubernetes

### 1.1 Pourquoi les volumes ?

Par défaut, les données dans un conteneur sont éphémères : elles disparaissent quand le conteneur s'arrête. Les volumes Kubernetes permettent de :

- **Persister les données** au-delà du cycle de vie d'un pod
- **Partager des données** entre conteneurs d'un même pod
- **Stocker des configurations** et des secrets
- **Monter des systèmes de fichiers externes**

### 1.2 Types de volumes

Kubernetes supporte plusieurs types de volumes :

- **emptyDir** : Volume temporaire, vie du pod
- **hostPath** : Monte un répertoire du nœud (développement uniquement)
- **persistentVolumeClaim** : Demande de stockage persistant
- **configMap/secret** : Pour les configurations
- **nfs, iscsi, cephfs** : Stockage réseau
- **cloud providers** : awsElasticBlockStore, gcePersistentDisk, azureDisk

### 1.3 Volume emptyDir

Le volume le plus simple, créé quand un pod est assigné à un nœud.

Créer le fichier `01-emptydir-pod.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
  labels:
    app: demo
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh"]
    args:
      - -c
      - >
        while true; do
          echo "$(date): Writing data" >> /data/log.txt;
          sleep 5;
        done
    volumeMounts:
    - name: shared-storage
      mountPath: /data

  - name: reader
    image: busybox
    command: ["/bin/sh"]
    args:
      - -c
      - >
        while true; do
          echo "=== Latest logs ===";
          tail -n 5 /data/log.txt;
          sleep 10;
        done
    volumeMounts:
    - name: shared-storage
      mountPath: /data

  volumes:
  - name: shared-storage
    emptyDir: {}
```

**Exercice 1 : Tester emptyDir**

```bash
# Appliquer le manifest
kubectl apply -f 01-emptydir-pod.yaml

# Vérifier que le pod tourne
kubectl get pods

# Observer les logs du writer
kubectl logs emptydir-demo -c writer

# Observer les logs du reader
kubectl logs emptydir-demo -c reader -f

# Supprimer le pod
kubectl delete -f 01-emptydir-pod.yaml
```

**Question** : Que se passe-t-il si vous recréez le pod ? Les données sont-elles toujours là ?

## Partie 2 : PersistentVolumes et PersistentVolumeClaims

### 2.1 Concepts fondamentaux

**PersistentVolume (PV)** :
- Ressource de stockage dans le cluster
- Indépendant du cycle de vie des pods
- Provisionné par l'administrateur ou dynamiquement

**PersistentVolumeClaim (PVC)** :
- Demande de stockage par un utilisateur
- Spécifie la taille et le mode d'accès
- Se lie automatiquement à un PV compatible

**Cycle de vie** :
1. **Provisioning** : Création du PV (statique ou dynamique)
2. **Binding** : Liaison PVC → PV
3. **Using** : Utilisation dans un pod
4. **Reclaiming** : Libération et recyclage

### 2.2 Modes d'accès

- **ReadWriteOnce (RWO)** : Lecture-écriture par un seul nœud
- **ReadOnlyMany (ROX)** : Lecture seule par plusieurs nœuds
- **ReadWriteMany (RWX)** : Lecture-écriture par plusieurs nœuds

### 2.3 Créer un PersistentVolume

Créer `02-persistent-volume.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-demo
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

**Exercice 2 : Créer un PV**

```bash
# Créer le répertoire sur le nœud minikube
minikube ssh "sudo mkdir -p /mnt/data"

# Créer le PV
kubectl apply -f 02-persistent-volume.yaml

# Vérifier le PV
kubectl get pv
kubectl describe pv pv-demo
```

Vous devriez voir le statut **Available**.

### 2.4 Créer un PersistentVolumeClaim

Créer `03-persistent-volume-claim.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

**Exercice 3 : Créer un PVC**

```bash
# Créer le PVC
kubectl apply -f 03-persistent-volume-claim.yaml

# Vérifier le PVC
kubectl get pvc
kubectl describe pvc pvc-demo

# Revérifier le PV
kubectl get pv
```

Le PV devrait maintenant être **Bound** au PVC.

### 2.5 Utiliser le PVC dans un Pod

Créer `04-pod-with-pvc.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-pvc
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: persistent-storage
      mountPath: /usr/share/nginx/html

  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: pvc-demo
```

**Exercice 4 : Tester la persistance**

```bash
# Créer le pod
kubectl apply -f 04-pod-with-pvc.yaml

# Attendre que le pod soit prêt
kubectl wait --for=condition=ready pod/pod-with-pvc --timeout=60s

# Écrire un fichier HTML dans le volume
kubectl exec pod-with-pvc -- sh -c 'echo "<h1>Persistent Data!</h1>" > /usr/share/nginx/html/index.html'

# Vérifier avec port-forward
kubectl port-forward pod/pod-with-pvc 8080:80 &
curl localhost:8080
pkill -f "port-forward"

# Supprimer le pod
kubectl delete pod pod-with-pvc

# Recréer le pod
kubectl apply -f 04-pod-with-pvc.yaml

# Attendre que le pod soit prêt
kubectl wait --for=condition=ready pod/pod-with-pvc --timeout=60s

# Vérifier que les données sont toujours là
kubectl exec pod-with-pvc -- cat /usr/share/nginx/html/index.html
```

Les données persistent malgré la suppression du pod !

## Partie 3 : StorageClass et provisionnement dynamique

### 3.1 Qu'est-ce qu'une StorageClass ?

Une StorageClass permet de définir différentes classes de stockage avec provisionnement automatique des PV.

**Avantages** :
- Pas besoin de créer les PV manuellement
- Provisionnement à la demande
- Différentes classes pour différents besoins (SSD, HDD, etc.)

### 3.2 StorageClass par défaut de minikube

```bash
# Lister les StorageClasses disponibles
kubectl get storageclass

# Décrire la StorageClass par défaut
kubectl describe storageclass standard
```

Minikube fournit une StorageClass `standard` utilisant le provisioner `k8s.io/minikube-hostpath`.

### 3.3 Créer une StorageClass personnalisée

Créer `05-storage-class.yaml` :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: k8s.io/minikube-hostpath
parameters:
  type: pd-ssd
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

```bash
# Créer la StorageClass
kubectl apply -f 05-storage-class.yaml

# Vérifier
kubectl get storageclass
```

### 3.4 PVC avec provisionnement dynamique

Créer `06-dynamic-pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

**Exercice 5 : Provisionnement dynamique**

```bash
# Créer le PVC
kubectl apply -f 06-dynamic-pvc.yaml

# Observer la création automatique du PV
kubectl get pvc dynamic-pvc
kubectl get pv

# Un PV a été créé automatiquement !
```

## Partie 4 : Cas pratique - Base de données MySQL

### 4.1 Déploiement MySQL avec persistance

Créer `07-mysql-deployment.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  mysql-root-password: "MotDePasseSecurise123"
  mysql-database: "app_db"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-database
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  clusterIP: None  # Headless service
```

**Exercice 6 : Déployer MySQL**

```bash
# Appliquer le manifest complet
kubectl apply -f 07-mysql-deployment.yaml

# Vérifier les ressources créées
kubectl get pvc mysql-pvc
kubectl get deployment mysql
kubectl get pods -l app=mysql
kubectl get svc mysql

# Attendre que MySQL soit prêt
kubectl wait --for=condition=ready pod -l app=mysql --timeout=120s

# Voir les logs de MySQL
kubectl logs -l app=mysql
```

### 4.2 Tester MySQL

```bash
# Se connecter à MySQL
kubectl exec -it deployment/mysql -- mysql -uroot -pMotDePasseSecurise123

# Dans le shell MySQL, exécuter :
# SHOW DATABASES;
# USE app_db;
# CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(50));
# INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob');
# SELECT * FROM users;
# EXIT;
```

**Exercice 7 : Vérifier la persistance**

```bash
# Supprimer le pod MySQL
kubectl delete pod -l app=mysql

# Attendre que le deployment recrée le pod
kubectl wait --for=condition=ready pod -l app=mysql --timeout=120s

# Se reconnecter
kubectl exec -it deployment/mysql -- mysql -uroot -pMotDePasseSecurise123

# Vérifier que les données sont toujours là :
# USE app_db;
# SELECT * FROM users;
# EXIT;
```

Les données ont survécu à la suppression du pod !

### 4.3 Client MySQL pour tester

Créer `08-mysql-client.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-client
spec:
  containers:
  - name: mysql-client
    image: mysql:8.0
    command: ['sh', '-c', 'sleep 3600']
```

```bash
# Créer le client
kubectl apply -f 08-mysql-client.yaml

# Se connecter depuis le client
kubectl exec -it mysql-client -- mysql -h mysql -uroot -pMotDePasseSecurise123

# Dans MySQL :
# USE app_db;
# SELECT * FROM users;
# EXIT;
```

## Partie 5 : Gestion avancée du stockage

### 5.1 Expansion de volume

```bash
# Vérifier que la StorageClass permet l'expansion
kubectl get storageclass standard -o yaml | grep allowVolumeExpansion

# Éditer le PVC pour augmenter la taille
kubectl edit pvc dynamic-pvc

# Modifier storage: 2Gi en storage: 5Gi
# Sauvegarder et quitter

# Vérifier l'expansion
kubectl get pvc dynamic-pvc
kubectl describe pvc dynamic-pvc
```

### 5.2 Politiques de réclamation (Reclaim Policies)

Les PV ont différentes politiques de réclamation :

- **Retain** : Conserver les données après suppression du PVC
- **Delete** : Supprimer le PV et les données (défaut pour provisionnement dynamique)
- **Recycle** : Effacer les données et rendre le PV disponible (obsolète)

Créer `09-pv-retain.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-retain
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: "/mnt/data-retain"
```

### 5.3 Snapshots de volumes (avancé)

Les snapshots permettent de créer des sauvegardes ponctuelles :

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: mysql-pvc
```

**Note** : La fonctionnalité de snapshot nécessite un driver CSI compatible.

## Partie 6 : Bonnes pratiques

### 6.1 Bonnes pratiques générales

1. **Utiliser le provisionnement dynamique** quand possible
   - Évite la gestion manuelle des PV
   - Simplifie les déploiements

2. **Définir des limites de ressources**
   - Spécifier la taille exacte nécessaire
   - Éviter le gaspillage de stockage

3. **Choisir le bon mode d'accès**
   - RWO pour bases de données
   - RWX pour applications multi-nœuds

4. **Utiliser des StorageClasses appropriées**
   - SSD pour performance
   - HDD pour stockage économique

5. **Sauvegarder régulièrement**
   - Utiliser des snapshots
   - Exporter les données critiques

### 6.2 Sécurité

```yaml
# Exemple de PVC avec annotations de sécurité
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: secure-pvc
  annotations:
    volume.beta.kubernetes.io/storage-class: "encrypted"
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 6.3 Monitoring du stockage

```bash
# Vérifier l'utilisation des PV
kubectl get pv

# Vérifier l'utilisation des PVC
kubectl get pvc --all-namespaces

# Décrire un PVC pour voir l'utilisation
kubectl describe pvc mysql-pvc

# Voir l'utilisation dans un pod
kubectl exec <pod-name> -- df -h /mount/path
```

## Partie 7 : Exercices pratiques

### Exercice Final 1 : Application web avec Redis

Créez un déploiement complet avec :
- Un deployment Redis avec PVC
- Un service pour exposer Redis
- Un deployment d'application web qui utilise Redis
- Vérifiez la persistance des données Redis

**Indices** :
```yaml
# Redis utilise le port 6379
# Données Redis stockées dans /data
# Image : redis:alpine
```

### Exercice Final 2 : Migration de données

1. Créez un pod avec un PVC
2. Écrivez des données dans le volume
3. Créez un snapshot (si disponible) ou sauvegardez manuellement
4. Supprimez le pod
5. Créez un nouveau pod avec le même PVC
6. Vérifiez que les données sont intactes

### Exercice Final 3 : Multi-applications partagées

Créez :
- Un PVC avec mode ReadWriteMany (si supporté par votre cluster)
- Deux deployments différents qui montent le même PVC
- Une application écrit des fichiers, l'autre les lit
- Testez le partage de données

## Partie 8 : Nettoyage

```bash
# Supprimer tous les pods, deployments et services
kubectl delete deployment mysql
kubectl delete service mysql
kubectl delete pod mysql-client
kubectl delete pod pod-with-pvc
kubectl delete pod emptydir-demo

# Supprimer les PVC
kubectl delete pvc mysql-pvc
kubectl delete pvc dynamic-pvc
kubectl delete pvc pvc-demo

# Supprimer les PV (si Retain)
kubectl delete pv pv-demo

# Supprimer les StorageClasses personnalisées
kubectl delete storageclass fast-storage

# Supprimer les secrets
kubectl delete secret mysql-secret

# Vérifier que tout est nettoyé
kubectl get all
kubectl get pvc
kubectl get pv
```

## Résumé

Dans ce TP, vous avez appris à :

- Utiliser différents types de volumes (emptyDir, hostPath, PVC)
- Créer et gérer des PersistentVolumes et PersistentVolumeClaims
- Utiliser le provisionnement dynamique avec StorageClasses
- Déployer une base de données avec persistance
- Appliquer les bonnes pratiques de gestion du stockage

### Concepts clés

- **Volume** : Abstraction de stockage
- **PV** : Ressource de stockage cluster-wide
- **PVC** : Demande de stockage par un utilisateur
- **StorageClass** : Classe de stockage avec provisionnement dynamique
- **Modes d'accès** : RWO, ROX, RWX
- **Reclaim Policy** : Retain, Delete, Recycle

## Ressources complémentaires

### Documentation officielle
- [Volumes Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)

### Tutoriels avancés
- [CSI Drivers](https://kubernetes-csi.github.io/docs/)
- [Rook (stockage distribué)](https://rook.io/)
- [Longhorn (stockage cloud-native)](https://longhorn.io/)

### Prochaines étapes

Félicitations ! Vous maîtrisez maintenant la persistance des données dans Kubernetes.

Passez au **TP4** pour apprendre le monitoring et la gestion des logs.

## Questions de révision

1. Quelle est la différence entre un Volume et un PersistentVolume ?
2. Quand utiliser emptyDir vs PVC ?
3. Qu'est-ce que le provisionnement dynamique ?
4. Quels sont les trois modes d'accès disponibles ?
5. Que se passe-t-il avec une Reclaim Policy "Delete" ?
6. Pourquoi utiliser un Headless Service pour MySQL ?
7. Comment vérifier qu'un volume est correctement monté dans un pod ?
8. Quelle est la différence entre requests et limits pour le stockage ?

## Solutions des questions

<details>
<summary>Cliquez pour voir les réponses</summary>

1. Un Volume est lié au cycle de vie d'un pod, un PV est une ressource cluster-wide indépendante
2. emptyDir pour données temporaires partagées entre conteneurs, PVC pour données persistantes
3. Création automatique de PV à la demande via une StorageClass
4. ReadWriteOnce, ReadOnlyMany, ReadWriteMany
5. Le PV et les données sont supprimés automatiquement
6. Pour accès direct aux pods sans load balancing
7. `kubectl describe pod <name>` et vérifier la section Mounts
8. Pour le stockage, requests = taille demandée, limits n'existe pas (la taille est fixe)

</details>

---

**Durée estimée du TP :** 4-5 heures
**Niveau :** Intermédiaire

**Bon travail !**
