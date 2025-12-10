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
- Un cluster Kubernetes fonctionnel (**minikube** ou **kubeadm**)
- Connaissance de base des manifests YAML

**Note :** Les concepts de persistance (PV, PVC, StorageClass) sont identiques pour minikube et kubeadm. Les différences se situent principalement au niveau des provisioners de stockage disponibles.

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

### 2.3 Créer la StorageClass pour le provisionnement manuel

Avant de créer des PersistentVolumes avec un provisionnement manuel, nous devons créer une StorageClass appropriée. Sans cette StorageClass, le binding entre le PV et le PVC échouera.

Créer `02-storage-class-manual.yaml` :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

**Explications importantes** :

- **provisioner: kubernetes.io/no-provisioner** : Indique qu'il n'y a pas de provisionnement automatique. Les PV doivent être créés manuellement par un administrateur.
- **volumeBindingMode: WaitForFirstConsumer** : Le binding du PVC au PV ne se fera que lorsqu'un pod utilisera le PVC. Cela évite de lier un volume à un nœud avant de savoir où le pod sera schedulé.

```bash
# Créer la StorageClass
kubectl apply -f 02-storage-class-manual.yaml

# Vérifier la création
kubectl get storageclass manual
kubectl describe storageclass manual
```

**Note** : Cette étape est cruciale. Sans cette StorageClass, vous obtiendrez une erreur lors du binding du PVC car Kubernetes ne trouvera pas la StorageClass "manual" référencée dans les manifests.

### 2.4 Créer un PersistentVolume

Créer `03-persistent-volume.yaml` :

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

**Avec minikube :**
```bash
# Créer le répertoire sur le nœud minikube
minikube ssh "sudo mkdir -p /mnt/data"
```

**Avec kubeadm :**
```bash
# Créer le répertoire sur chaque worker (adapter le nom d'utilisateur et l'IP)
ssh user@worker-node-1 "sudo mkdir -p /mnt/data"
ssh user@worker-node-2 "sudo mkdir -p /mnt/data"

# Ou sur tous les nœuds si vous autorisez le scheduling sur le master
for node in master-node worker-node-1 worker-node-2; do
  ssh user@$node "sudo mkdir -p /mnt/data"
done
```

**Création du PV (identique pour minikube et kubeadm) :**
```bash
# Créer le PV
kubectl apply -f 03-persistent-volume.yaml

# Vérifier le PV
kubectl get pv
kubectl describe pv pv-demo
```

Vous devriez voir le statut **Available**.

### 2.5 Créer un PersistentVolumeClaim

Créer `04-persistent-volume-claim.yaml` :

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

**Note importante sur le binding** :

Le PVC va chercher un PV compatible avec les critères suivants :
- Même `storageClassName` (ici: "manual")
- Mode d'accès compatible (ici: ReadWriteOnce)
- Capacité suffisante (ici: 500Mi, le PV a 1Gi donc c'est OK)

⚠️ **Problème courant** : Si vous voyez le PVC rester en état "Pending" indéfiniment, vérifiez que :
1. La StorageClass "manual" a bien été créée (section 2.3)
2. Un PV avec `storageClassName: manual` existe et est en état "Available"
3. Les modes d'accès et la capacité correspondent

Sans la StorageClass "manual", le binding échouera et vous verrez une erreur du type : "storageclass.storage.k8s.io 'manual' not found".

**Exercice 3 : Créer un PVC**

```bash
# Créer le PVC
kubectl apply -f 04-persistent-volume-claim.yaml

# Vérifier le PVC
kubectl get pvc
kubectl describe pvc pvc-demo

# Revérifier le PV
kubectl get pv
```

Le PV devrait maintenant être **Bound** au PVC.

### 2.6 Utiliser le PVC dans un Pod

Créer `05-pod-with-pvc.yaml` :

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
kubectl apply -f 05-pod-with-pvc.yaml

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
kubectl apply -f 05-pod-with-pvc.yaml

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

### 3.2 StorageClass par défaut

```bash
# Lister les StorageClasses disponibles
kubectl get storageclass

# Décrire la StorageClass par défaut
kubectl describe storageclass standard
```

**Avec minikube :** La StorageClass `standard` utilise le provisioner `k8s.io/minikube-hostpath`.

**Avec kubeadm :** La StorageClass par défaut dépend de votre installation. Avec l'installation de base kubeadm, **aucune StorageClass** n'est créée par défaut. Vous devez :
- Soit installer un provisioner comme [local-path-provisioner](https://github.com/rancher/local-path-provisioner)
- Soit utiliser un provisioner cloud si vous êtes sur un cloud provider
- Soit créer manuellement les PV (provisionnement statique)

**Installation de local-path-provisioner pour kubeadm :**
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Définir comme StorageClass par défaut
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Vérifier
kubectl get storageclass
```

### 3.3 Créer une StorageClass personnalisée

**Pour minikube :**

Créer `06-storage-class-minikube.yaml` :

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

**Pour kubeadm (avec local-path-provisioner) :**

Créer `06-storage-class-kubeadm.yaml` :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

```bash
# Créer la StorageClass (adapter le nom du fichier selon votre environnement)
kubectl apply -f 06-storage-class-minikube.yaml  # Pour minikube
# OU
kubectl apply -f 06-storage-class-kubeadm.yaml   # Pour kubeadm

# Vérifier
kubectl get storageclass
```

### 3.4 PVC avec provisionnement dynamique

Créer `07-dynamic-pvc.yaml` :

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
kubectl apply -f 07-dynamic-pvc.yaml

# Observer la création automatique du PV
kubectl get pvc dynamic-pvc
kubectl get pv

# Un PV a été créé automatiquement !
```

## Partie 4 : Cas pratique - Base de données MySQL

### 4.1 Déploiement MySQL avec persistance

Créer `08-mysql-deployment.yaml` :

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
kubectl apply -f 08-mysql-deployment.yaml

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

Créer `09-mysql-client.yaml` :

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
kubectl apply -f 09-mysql-client.yaml

# Se connecter depuis le client
kubectl exec -it mysql-client -- mysql -h mysql -uroot -pMotDePasseSecurise123

# Dans MySQL :
# USE app_db;
# SELECT * FROM users;
# EXIT;
```

## Partie 5 : Gestion avancée du stockage

### 5.1 Expansion de volume

L'expansion de volume permet d'augmenter la taille d'un PVC existant sans recréer le volume. Cette fonctionnalité dépend de deux conditions :

1. La StorageClass doit avoir `allowVolumeExpansion: true`
2. Le driver de stockage doit supporter l'expansion

**Étape 1 : Vérifier que la StorageClass permet l'expansion**

```bash
# Vérifier la StorageClass standard de minikube
kubectl get storageclass standard -o yaml | grep allowVolumeExpansion
```

**Important** : Si `allowVolumeExpansion` n'est pas présent ou est `false`, vous avez deux options :

**Option A** : Utiliser la StorageClass `fast-storage` créée dans la partie 3.3 qui supporte l'expansion :

```bash
# Créer un nouveau PVC avec fast-storage
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  storageClassName: fast-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

# Vérifier que le PVC est bien créé
kubectl get pvc expandable-pvc

# Éditer le PVC pour augmenter la taille
kubectl edit pvc expandable-pvc

# Modifier storage: 2Gi en storage: 5Gi
# Sauvegarder et quitter

# Vérifier l'expansion
kubectl get pvc expandable-pvc
kubectl describe pvc expandable-pvc
```

**Option B** : Activer l'expansion sur la StorageClass standard (si vous avez les permissions) :

```bash
# Éditer la StorageClass standard
kubectl patch storageclass standard -p '{"allowVolumeExpansion": true}'

# Vérifier la modification
kubectl get storageclass standard -o yaml | grep allowVolumeExpansion

# Maintenant vous pouvez éditer le PVC dynamic-pvc
kubectl edit pvc dynamic-pvc

# Modifier storage: 2Gi en storage: 5Gi
# Sauvegarder et quitter

# Vérifier l'expansion
kubectl get pvc dynamic-pvc
kubectl describe pvc dynamic-pvc
```

**Note** : L'expansion de volume peut nécessiter un redémarrage du pod utilisant le PVC pour que la nouvelle taille soit reconnue par le système de fichiers.

#### 5.1.1 Troubleshooting : La taille n'a pas changé

Si après l'expansion du PVC, la taille ne se reflète pas dans le pod, voici les étapes de diagnostic et résolution :

**Étape 1 : Vérifier le statut du PVC**

```bash
# Vérifier l'état de l'expansion
kubectl get pvc <nom-du-pvc>
kubectl describe pvc <nom-du-pvc>

# Chercher des messages comme :
# - "Waiting for user to (re-)start a pod to finish file system resize"
# - "FileSystemResizePending"
```

**Étape 2 : Vérifier la taille dans le pod**

```bash
# Vérifier la taille actuelle du volume dans le pod
kubectl exec <nom-du-pod> -- df -h <point-de-montage>

# Exemple avec le PVC monté sur /data :
kubectl exec my-pod -- df -h /data
```

**Solutions selon le problème identifié :**

**Solution 1 : Redémarrer le pod (le plus courant)**

```bash
# Si c'est un pod autonome
kubectl delete pod <nom-du-pod>
kubectl apply -f <fichier-du-pod>.yaml

# Si c'est un Deployment
kubectl rollout restart deployment <nom-du-deployment>

# Attendre que le nouveau pod soit prêt
kubectl wait --for=condition=ready pod -l app=<label> --timeout=120s

# Vérifier à nouveau la taille
kubectl exec <nom-du-pod> -- df -h <point-de-montage>
```

**Solution 2 : Redimensionner manuellement le système de fichiers**

Si le redémarrage du pod ne suffit pas, il faut redimensionner manuellement le système de fichiers :

```bash
# Pour un système de fichiers ext4
kubectl exec <nom-du-pod> -- resize2fs <device>

# Exemple avec le device par défaut
kubectl exec my-pod -- sh -c 'df -h /data && resize2fs $(df /data | tail -1 | cut -d" " -f1) && df -h /data'

# Pour un système de fichiers XFS
kubectl exec <nom-du-pod> -- xfs_growfs <point-de-montage>

# Exemple
kubectl exec my-pod -- xfs_growfs /data
```

**Solution 3 : Vérifier les conditions du PVC**

```bash
# Afficher les détails complets du PVC
kubectl get pvc <nom-du-pvc> -o yaml

# Chercher dans status.conditions pour des erreurs
# Vérifier status.capacity vs spec.resources.requests.storage
```

**Solution 4 : Vérifier les logs du contrôleur**

```bash
# Vérifier les logs du provisioner de stockage
kubectl logs -n kube-system -l app=storage-provisioner

# Pour minikube spécifiquement
minikube logs | grep -i "resize\|expand"
```

**Exemple complet de test d'expansion :**

```bash
# 1. Créer un pod de test avec le PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-expansion
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: expandable-pvc
EOF

# 2. Vérifier la taille initiale
kubectl exec test-expansion -- df -h /data

# 3. Étendre le PVC
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'

# 4. Vérifier le statut de l'expansion
kubectl describe pvc expandable-pvc

# 5. Redémarrer le pod
kubectl delete pod test-expansion
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-expansion
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: expandable-pvc
EOF

# 6. Attendre et vérifier la nouvelle taille
kubectl wait --for=condition=ready pod/test-expansion --timeout=60s
kubectl exec test-expansion -- df -h /data

# Nettoyage
kubectl delete pod test-expansion
```

**Limitations connues :**

- Certains drivers de stockage ne supportent que l'expansion en ligne (sans redémarrage)
- D'autres nécessitent obligatoirement un redémarrage du pod
- L'expansion n'est jamais possible en réduction (shrink), seulement en augmentation
- Le provisioner `k8s.io/minikube-hostpath` supporte l'expansion mais nécessite un redémarrage

### 5.2 Installation du driver CSI

Pour utiliser des fonctionnalités avancées comme les snapshots de volumes, il est nécessaire d'installer le driver CSI (Container Storage Interface).

**Pourquoi installer le CSI driver ?**

Le driver CSI `csi-hostpath-driver` permet :
- La création de snapshots de volumes
- La restauration de volumes à partir de snapshots
- Le clonage de volumes
- Une gestion plus avancée du stockage

#### Option A : Avec minikube

```bash
# Activer l'addon csi-hostpath-driver sur minikube
minikube addons enable csi-hostpath-driver

# Vérifier que l'addon est activé
minikube addons list | grep csi-hostpath-driver

# Attendre que les pods CSI soient prêts
kubectl wait --for=condition=ready pod -n kube-system -l app=csi-hostpath-driver --timeout=120s
```

#### Option B : Avec kubeadm

**Installation manuelle du csi-hostpath-driver :**

```bash
# Cloner le repo du driver CSI hostpath
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
cd csi-driver-host-path

# Déployer le driver
./deploy/kubernetes-latest/deploy.sh

# Vérifier le déploiement
kubectl get pods -n default | grep csi

# Attendre que les pods soient prêts
kubectl wait --for=condition=ready pod -l app=csi-hostpathplugin --timeout=120s
```

**Alternative : Utiliser le manifest direct :**

```bash
# Installer les CRDs pour les snapshots
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# Installer le snapshot controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# Installer le driver hostpath
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/deploy/kubernetes-latest/hostpath/csi-hostpath-driverinfo.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-host-path/master/deploy/kubernetes-latest/hostpath/csi-hostpath-plugin.yaml
```

**Vérification de l'installation**

```bash
# Vérifier les pods CSI dans kube-system
kubectl get pods -n kube-system | grep csi

# Vérifier la VolumeSnapshotClass créée automatiquement
kubectl get volumesnapshotclass

# Vérifier le driver CSI
kubectl get csidrivers
```

Vous devriez voir :
- Les pods `csi-hostpath-driver-*` en état `Running`
- Une `VolumeSnapshotClass` nommée `csi-hostpath-snapclass`
- Le driver `hostpath.csi.k8s.io` dans la liste des CSI drivers

**Note** : Sur minikube, le driver CSI utilise également le stockage local du nœud, mais offre des fonctionnalités supplémentaires par rapport au provisioner standard.

### 5.3 Politiques de réclamation (Reclaim Policies)

Les PV ont différentes politiques de réclamation :

- **Retain** : Conserver les données après suppression du PVC
- **Delete** : Supprimer le PV et les données (défaut pour provisionnement dynamique)
- **Recycle** : Effacer les données et rendre le PV disponible (obsolète)

Créer `10-pv-retain.yaml` :

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

### 5.4 Snapshots de volumes (avancé)

Les snapshots permettent de créer des sauvegardes ponctuelles de vos volumes. Grâce au driver CSI installé dans la section précédente, vous pouvez maintenant créer des snapshots.

**Installation de la VolumeSnapshotClass sur minikube**

Sur minikube, même après avoir activé l'addon `csi-hostpath-driver`, la `VolumeSnapshotClass` nécessaire pour créer des snapshots n'est pas automatiquement créée. Il faut activer un addon supplémentaire.

```bash
# Activer l'addon volumesnapshots (qui inclut csi-hostpath-snapclass)
minikube addons enable volumesnapshots

# Vérifier que l'addon est activé
minikube addons list | grep volumesnapshots

# Vérifier que la VolumeSnapshotClass a été créée
kubectl get volumesnapshotclass

# Vous devriez voir : csi-hostpath-snapclass
```

**Alternative : Créer manuellement la VolumeSnapshotClass**

Si l'addon `volumesnapshots` n'est pas disponible, vous pouvez créer manuellement la VolumeSnapshotClass :

```bash
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-hostpath-snapclass
driver: hostpath.csi.k8s.io
deletionPolicy: Delete
EOF

# Vérifier la création
kubectl get volumesnapshotclass
kubectl describe volumesnapshotclass csi-hostpath-snapclass
```

**Note importante** : Sans la VolumeSnapshotClass, vous obtiendrez une erreur lors de la création de snapshots indiquant que la classe n'existe pas.

**Création d'un snapshot**

Créer `11-volume-snapshot.yaml` :

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

**Exercice 8 : Créer et utiliser un snapshot**

```bash
# 1. Créer le snapshot du PVC MySQL
kubectl apply -f 11-volume-snapshot.yaml

# 2. Vérifier le snapshot
kubectl get volumesnapshot
kubectl describe volumesnapshot mysql-snapshot

# 3. Restaurer depuis un snapshot - créer un nouveau PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc-restored
spec:
  storageClassName: csi-hostpath-sc
  dataSource:
    name: mysql-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# 4. Vérifier le nouveau PVC
kubectl get pvc mysql-pvc-restored
```

**Note** : Les snapshots sont utiles pour :
- Sauvegardes avant modifications importantes
- Clonage rapide de volumes
- Tests et développement
- Récupération après incident

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
