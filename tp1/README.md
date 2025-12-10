# TP1 - Premier déploiement Kubernetes sur AlmaLinux

> **💻 Utilisateurs Windows :** Consultez le [guide spécifique Windows (WINDOWS.md)](WINDOWS.md) qui adapte ce TP pour Windows avec Minikube ou WSL2. Voir aussi le [guide d'installation Windows complet](../docs/WINDOWS_SETUP.md).

## Objectifs du TP

À la fin de ce TP, vous serez capable de :
- Installer et configurer un cluster Kubernetes (minikube ou kubeadm)
- Démarrer un cluster Kubernetes
- Déployer votre première application
- Exposer l'application via un service
- Interagir avec les pods et services

## Prérequis

### Pour minikube (développement local)
- Une machine AlmaLinux (physique ou virtuelle) **ou Windows** ([voir guide Windows](WINDOWS.md))
- 2 CPU minimum (4 CPU recommandé pour Windows)
- 2 Go de RAM minimum (4 Go recommandé pour Windows)
- 20 Go d'espace disque
- Accès root ou sudo (ou droits administrateur sur Windows)

### Pour kubeadm (environnement multi-nœuds)
- 2-3 machines AlmaLinux (1 master + 1-2 workers) **ou WSL2 sur Windows**
- **Master :** 2 CPU, 2 Go RAM, 20 Go disque
- **Workers :** 1 CPU, 1 Go RAM, 20 Go disque
- Réseau entre les machines
- Accès root ou sudo

## Choix de votre environnement

Ce TP peut être réalisé avec **deux approches différentes** :

### Option A : minikube (recommandé pour débuter)
- ✅ Installation rapide et simple
- ✅ Idéal pour le développement local
- ✅ Nécessite une seule machine
- ✅ Gestion automatique du réseau
- ❌ Ne reflète pas un environnement de production
- ❌ Limitations pour le multi-nœud

### Option B : kubeadm (recommandé pour la production)
- ✅ Architecture réaliste multi-nœuds
- ✅ Proche d'un environnement de production
- ✅ Contrôle total sur la configuration
- ✅ Scalabilité native
- ❌ Installation plus complexe
- ❌ Nécessite plusieurs machines

**💡 Conseil :** Commencez avec minikube pour apprendre les concepts, puis passez à kubeadm pour comprendre la production.

---

## Partie 1 : Installation de l'environnement

### 1.1 Mise à jour du système

```bash
sudo dnf update -y
```

### 1.2 Installation de Docker

```bash
# Installer les dépendances
sudo dnf install -y yum-utils device-mapper-persistent-data lvm2

# Ajouter le repository Docker
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Installer Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io

# Démarrer et activer Docker
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Appliquer les changements (ou se reconnecter)
newgrp docker
```

### 1.3 Installation de kubectl

```bash
# Télécharger kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Rendre le binaire exécutable
chmod +x kubectl

# Déplacer vers /usr/local/bin
sudo mv kubectl /usr/local/bin/

# Vérifier l'installation
kubectl version --client
```

### 1.4 Installation de minikube (Option A)

**Si vous choisissez minikube :**

```bash
# Télécharger minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Installer minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Vérifier l'installation
minikube version
```

### 1.5 Installation de kubeadm (Option B)

**Si vous choisissez kubeadm :**

Pour une installation complète avec kubeadm, consultez le **[Guide d'installation kubeadm](../docs/KUBEADM_SETUP.md)** qui couvre :
- La préparation des nœuds (désactivation swap, modules kernel, etc.)
- L'installation de containerd
- L'installation de kubeadm, kubelet et kubectl
- L'initialisation du cluster
- L'ajout de workers
- La configuration du réseau (CNI)

**Installation rapide (résumé) :**

```bash
# Sur TOUS les nœuds (master et workers)

# 1. Désactiver swap et SELinux
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 2. Configurer les modules kernel
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 3. Installer containerd
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 4. Installer kubeadm, kubelet et kubectl
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
```

**Sur le nœud MASTER uniquement :**

```bash
# Initialiser le cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurer kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installer Flannel (CNI)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

**Sur chaque nœud WORKER :**

```bash
# Utiliser la commande 'kubeadm join' affichée après l'init sur le master
# Exemple :
# sudo kubeadm join <master-ip>:6443 --token <token> \
#   --discovery-token-ca-cert-hash sha256:<hash>
```

**💡 Note :** Consultez le [guide complet kubeadm](../docs/KUBEADM_SETUP.md) pour plus de détails et le dépannage.

---

## Partie 2 : Démarrage du cluster Kubernetes

### 2.1 Option A : Démarrer minikube

**Si vous utilisez minikube :**

```bash
# Démarrer minikube avec Docker comme driver
minikube start --driver=docker

# Vérifier le statut
minikube status
```

**Résultat attendu :**
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

### 2.1 Option B : Vérifier le cluster kubeadm

**Si vous utilisez kubeadm :**

Après avoir suivi les étapes d'installation de la section 1.5, vérifiez que votre cluster est opérationnel :

```bash
# Vérifier que tous les pods système sont prêts
kubectl get pods -n kube-system

# Attendre que tous les pods soient Running
kubectl wait --for=condition=ready pod --all -n kube-system --timeout=300s
```

**Résultat attendu :** Tous les pods (coredns, flannel, kube-proxy, etc.) doivent être en état `Running`.

### 2.2 Vérifier le cluster

**Ces commandes fonctionnent pour minikube ET kubeadm :**

```bash
# Afficher les informations du cluster
kubectl cluster-info

# Lister les nœuds
kubectl get nodes

# Afficher plus de détails sur les nœuds
kubectl describe nodes
```

**Avec minikube, vous verrez :**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   5m    v1.29.0
```

**Avec kubeadm (exemple 1 master + 2 workers), vous verrez :**
```
NAME              STATUS   ROLES           AGE   VERSION
master-node       Ready    control-plane   10m   v1.29.0
worker-node-1     Ready    <none>          5m    v1.29.0
worker-node-2     Ready    <none>          4m    v1.29.0
```

## Partie 3 : Premier déploiement

### 3.1 Déployer une application Nginx

```bash
# Créer un déploiement nginx
kubectl create deployment nginx-demo --image=nginx:latest

# Vérifier le déploiement
kubectl get deployments

# Vérifier les pods
kubectl get pods
```

### 3.2 Examiner le pod

```bash
# Obtenir plus d'informations sur le pod
kubectl get pods -o wide

# Décrire le pod (remplacer <pod-name> par le nom réel)
kubectl describe pod <pod-name>

# Voir les logs du pod
kubectl logs <pod-name>
```

## Partie 4 : Comprendre les types de Service Kubernetes

Avant d'exposer notre application, il est important de comprendre les différents types de services disponibles dans Kubernetes. Un **Service** est une abstraction qui définit un ensemble logique de pods et une politique d'accès à ces pods.

### 4.1 Les trois types de Service principaux

#### ClusterIP (par défaut)

**Description :** Expose le service sur une IP interne au cluster. Ce type rend le service accessible uniquement depuis l'intérieur du cluster Kubernetes.

**Cas d'usage :**
- Communication entre services internes (ex: backend vers base de données)
- Services qui ne doivent pas être accessibles depuis l'extérieur
- Micro-services communiquant entre eux

**Exemple :**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-internal-service
spec:
  type: ClusterIP  # Peut être omis car c'est la valeur par défaut
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 80          # Port du service
    targetPort: 8080  # Port du conteneur
```

**Schéma conceptuel :**
```
┌─────────────────────────────────────┐
│         Cluster Kubernetes          │
│                                     │
│  ┌──────────┐      ┌──────────┐   │
│  │  Pod A   │─────▶│ Service  │   │
│  └──────────┘      │ClusterIP │   │
│                    │ 10.0.0.5 │   │
│  ┌──────────┐      └──────────┘   │
│  │  Pod B   │─────▶      │         │
│  └──────────┘            ▼         │
│                    ┌──────────┐    │
│                    │  Pods    │    │
│                    │  Backend │    │
│                    └──────────┘    │
└─────────────────────────────────────┘
```

#### NodePort

**Description :** Expose le service sur un port statique de chaque nœud du cluster. Kubernetes alloue automatiquement un port dans la plage 30000-32767 (configurable). Le service devient accessible depuis l'extérieur via `<NodeIP>:<NodePort>`.

**Cas d'usage :**
- Environnements de développement/test (comme minikube)
- Applications qui doivent être accessibles depuis l'extérieur sans load balancer
- Accès direct pour le débogage

**Exemple :**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nodeport-service
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 80           # Port du service
    targetPort: 8080   # Port du conteneur
    nodePort: 30080    # Port sur chaque nœud (optionnel, sinon auto-assigné)
```

**Schéma conceptuel :**
```
┌────────────────────────────────────────┐
│          Cluster Kubernetes            │
│                                        │
│  ┌────────────┐    ┌──────────┐      │
│  │   Node     │    │ Service  │      │
│  │192.168.1.10│    │ NodePort │      │
│  │Port: 30080 │◀───│          │      │
│  └────────────┘    └──────────┘      │
│         │                 │           │
│         └────────────▶┌──────────┐   │
│                       │  Pods    │   │
│                       │  Backend │   │
│                       └──────────┘   │
└────────────────────────────────────────┘
         ▲
         │
    ┌────────┐
    │ Client │ accède via http://192.168.1.10:30080
    │Externe │
    └────────┘
```

#### LoadBalancer

**Description :** Expose le service via un load balancer externe fourni par le cloud provider (AWS ELB, GCP Load Balancer, Azure Load Balancer, etc.). C'est une extension du type NodePort : un service LoadBalancer crée automatiquement un NodePort et demande au cloud provider de créer un load balancer pointant vers ce NodePort.

**Cas d'usage :**
- Applications en production sur des plateformes cloud
- Services qui nécessitent une IP publique stable
- Distribution automatique du trafic avec haute disponibilité

**Exemple :**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-loadbalancer-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 80           # Port du load balancer
    targetPort: 8080   # Port du conteneur
```

**Schéma conceptuel :**
```
    ┌────────┐
    │ Client │
    │Internet│
    └────┬───┘
         │
         ▼
┌──────────────────┐
│  Load Balancer   │  ◀─── IP Publique: 203.0.113.10
│  (Cloud Provider)│
└────────┬─────────┘
         │
┌────────┴───────────────────────────────┐
│         Cluster Kubernetes             │
│                                        │
│  ┌────────────┐    ┌──────────┐      │
│  │   Nodes    │    │ Service  │      │
│  │:30080-32767│◀───│LoadBal.  │      │
│  └────────────┘    └──────────┘      │
│         │                 │           │
│         └────────────▶┌──────────┐   │
│                       │  Pods    │   │
│                       │  Backend │   │
│                       └──────────┘   │
└────────────────────────────────────────┘
```

**Note sur minikube :** Dans un environnement minikube (cluster local), le type LoadBalancer sera automatiquement converti en NodePort car il n'y a pas de cloud provider pour créer un vrai load balancer. Minikube fournit la commande `minikube tunnel` pour simuler un load balancer en environnement local.

### 4.2 Tableau comparatif

| Type | Accessible depuis | IP externe | Cas d'usage principal | Port Range |
|------|-------------------|------------|----------------------|------------|
| **ClusterIP** | Cluster uniquement | Non | Services internes | Port du service (ex: 80, 3306) |
| **NodePort** | Externe (NodeIP:Port) | Non | Dev/Test, accès direct | 30000-32767 |
| **LoadBalancer** | Externe (via LB) | Oui | Production cloud | Standard (80, 443, etc.) |

### 4.3 Comment choisir le bon type ?

```
Besoin d'accès externe ?
│
├─ NON  ──▶ ClusterIP
│           (communication interne)
│
└─ OUI
    │
    ├─ Environnement local/dev ?
    │  OUI ──▶ NodePort
    │          (accès via IP:Port du nœud)
    │
    └─ NON (Production cloud)
       └──▶ LoadBalancer
            (IP publique + distribution)
```

## Partie 5 : Exposition de l'application

### 5.1 Créer un service

```bash
# Exposer le déploiement via un service de type NodePort
kubectl expose deployment nginx-demo --type=NodePort --port=80

# Vérifier le service
kubectl get services
```

**Note :** Nous utilisons NodePort ici car minikube est un environnement local. Pour comprendre quand utiliser NodePort vs ClusterIP vs LoadBalancer, référez-vous à la section 4 ci-dessus.

### 5.2 Accéder à l'application

#### Option A : Avec minikube

```bash
# Obtenir l'URL du service
minikube service nginx-demo --url

# Ou ouvrir directement dans le navigateur
minikube service nginx-demo
```

**Alternative avec curl :**
```bash
# Récupérer l'IP et le port
export NODE_PORT=$(kubectl get services nginx-demo -o jsonpath='{.spec.ports[0].nodePort}')
export NODE_IP=$(minikube ip)

# Tester l'accès
curl http://$NODE_IP:$NODE_PORT
```

#### Option B : Avec kubeadm

Avec kubeadm, vous accédez au service via l'IP de n'importe quel nœud et le NodePort :

```bash
# Récupérer le NodePort assigné
export NODE_PORT=$(kubectl get services nginx-demo -o jsonpath='{.spec.ports[0].nodePort}')

# Récupérer l'IP d'un worker (ou du master si scheduling autorisé)
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Afficher l'URL
echo "Service accessible à : http://$NODE_IP:$NODE_PORT"

# Tester l'accès
curl http://$NODE_IP:$NODE_PORT
```

**Note :** Avec kubeadm en multi-nœuds, le service est accessible via **n'importe quel nœud** du cluster grâce à kube-proxy, même si le pod n'est pas sur ce nœud.

**Astuce :** Pour un accès plus simple en production, considérez :
- **Ingress Controller** : Pour le routage HTTP/HTTPS (voir TPs suivants)
- **MetalLB** : Pour des LoadBalancers avec IP externe (voir [guide kubeadm](../docs/KUBEADM_SETUP.md#partie-6--configuration-du-loadbalancer-metallb))
- **HAProxy/Nginx externe** : Pour load balancer devant les NodePorts

## Partie 6 : Manipulation avancée

### 6.1 Scaler l'application

```bash
# Augmenter le nombre de réplicas à 3
kubectl scale deployment nginx-demo --replicas=3

# Vérifier les pods
kubectl get pods

# Observer la distribution
kubectl get pods -o wide
```

### 6.2 Mettre à jour l'application

```bash
# Mettre à jour l'image vers une version spécifique
kubectl set image deployment/nginx-demo nginx=nginx:1.24

# Suivre le rollout
kubectl rollout status deployment/nginx-demo

# Voir l'historique des déploiements
kubectl rollout history deployment/nginx-demo
```

### 6.3 Revenir à la version précédente

```bash
# Annuler le dernier déploiement
kubectl rollout undo deployment/nginx-demo

# Vérifier le statut
kubectl rollout status deployment/nginx-demo
```

## Partie 7 : Utilisation de fichiers YAML

### 7.1 Créer un fichier de déploiement

Créer un fichier `webapp-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: httpd:2.4
        ports:
        - containerPort: 80
```

### 7.2 Créer un fichier de service

Créer un fichier `webapp-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
```

**Note :** Ce service utilise un NodePort fixe (30080) ce qui est pratique pour le développement. Consultez la Partie 4 pour comprendre quand utiliser ce type de service.

### 7.3 Appliquer les configurations

```bash
# Appliquer le déploiement
kubectl apply -f webapp-deployment.yaml

# Appliquer le service
kubectl apply -f webapp-service.yaml

# Vérifier les ressources créées
kubectl get deployments,services,pods
```

### 7.4 Tester l'application

#### Option A : Avec minikube

```bash
# Accéder au service
curl http://$(minikube ip):30080
```

#### Option B : Avec kubeadm

```bash
# Récupérer l'IP d'un nœud
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Tester l'accès
curl http://$NODE_IP:30080

# Ou depuis un autre serveur sur le réseau
# curl http://<IP-du-noeud>:30080
```

**Note :** Avec kubeadm, le service est accessible sur le port 30080 depuis n'importe quel nœud du cluster grâce à kube-proxy.

## Partie 8 : Nettoyage et commandes utiles

### 8.1 Nettoyer les ressources

```bash
# Supprimer le déploiement nginx-demo
kubectl delete deployment nginx-demo
kubectl delete service nginx-demo

# Supprimer les ressources webapp
kubectl delete -f webapp-deployment.yaml
kubectl delete -f webapp-service.yaml

# Ou supprimer par nom
kubectl delete deployment webapp
kubectl delete service webapp-service
```

### 8.2 Commandes utiles

#### Communes (minikube et kubeadm)

```bash
# Voir toutes les ressources dans le namespace par défaut
kubectl get all

# Voir les pods de tous les namespaces
kubectl get pods --all-namespaces

# Afficher les événements récents
kubectl get events --sort-by='.lastTimestamp'
```

#### Spécifiques minikube

```bash
# Accéder au dashboard Kubernetes
minikube dashboard

# Voir les addons disponibles
minikube addons list

# Activer un addon (exemple: metrics-server)
minikube addons enable metrics-server

# Voir les logs de minikube
minikube logs

# SSH dans le nœud minikube
minikube ssh
```

#### Spécifiques kubeadm

```bash
# Installer le dashboard manuellement
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Créer un token pour accéder au dashboard
kubectl -n kubernetes-dashboard create token admin-user

# Accéder au dashboard via port-forward
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443

# Installer metrics-server manuellement
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# SSH dans un nœud spécifique (adapter l'IP)
ssh user@<node-ip>

# Voir les logs des composants système
kubectl logs -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

### 8.3 Arrêter et supprimer le cluster

#### Avec minikube

```bash
# Arrêter minikube
minikube stop

# Supprimer le cluster
minikube delete

# Démarrer à nouveau
minikube start
```

#### Avec kubeadm

```bash
# Pour arrêter le cluster, arrêter les VMs/serveurs ou :
# Sur chaque nœud
sudo systemctl stop kubelet

# Pour redémarrer
sudo systemctl start kubelet

# Pour supprimer complètement le cluster
# Sur tous les nœuds (master et workers)
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube/config
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Puis réinitialiser depuis le début si nécessaire (voir section 1.5)
```

## Exercices pratiques

### Exercice 1 : Déploiement Redis
1. Déployer une instance Redis avec l'image `redis:7-alpine`
2. L'exposer via un service de type **ClusterIP** sur le port 6379
3. Vérifier que le pod est en cours d'exécution

**Pourquoi ClusterIP ?** Redis est typiquement une base de données backend qui doit être accessible uniquement depuis l'intérieur du cluster par d'autres applications. Il n'a pas besoin d'être exposé à l'extérieur. Voir Partie 4.1 pour plus de détails sur ClusterIP.

### Exercice 2 : Application multi-conteneurs
1. Créer un déploiement avec 3 réplicas d'nginx
2. Créer un service **LoadBalancer**
3. Tester l'accès à l'application
4. Scaler à 5 réplicas
5. Observer la distribution des pods

**À propos de LoadBalancer :**
- **Avec minikube :** Le type LoadBalancer est automatiquement converti en NodePort. Pour simuler un vrai LoadBalancer localement, vous pouvez utiliser `minikube tunnel` dans un terminal séparé.
- **Avec kubeadm :** Installez MetalLB pour obtenir des IPs externes pour vos LoadBalancers (voir [guide kubeadm](../docs/KUBEADM_SETUP.md#partie-6--configuration-du-loadbalancer-metallb))

### Exercice 3 : Manipulation YAML
1. Créer un fichier YAML pour déployer MySQL
   - Image: `mysql:8.0`
   - Variables d'environnement: `MYSQL_ROOT_PASSWORD=secret`
   - Port: 3306
2. Appliquer le déploiement
3. Vérifier les logs du pod MySQL

## Solutions des exercices

<details>
<summary>Solution Exercice 1</summary>

```bash
# Créer le déploiement
kubectl create deployment redis-demo --image=redis:7-alpine

# Créer le service
kubectl expose deployment redis-demo --type=ClusterIP --port=6379

# Vérifier
kubectl get pods,services
```
</details>

<details>
<summary>Solution Exercice 2</summary>

```bash
# Créer le déploiement
kubectl create deployment nginx-multi --image=nginx --replicas=3

# Exposer le service
kubectl expose deployment nginx-multi --type=LoadBalancer --port=80

# Obtenir l'URL
minikube service nginx-multi --url

# Scaler
kubectl scale deployment nginx-multi --replicas=5

# Observer
kubectl get pods -o wide
```
</details>

<details>
<summary>Solution Exercice 3</summary>

Fichier `mysql-deployment.yaml` :
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
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
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: secret
        ports:
        - containerPort: 3306
```

Commandes :
```bash
kubectl apply -f mysql-deployment.yaml
kubectl get pods
kubectl logs <mysql-pod-name>
```
</details>

## Dépannage

### Problème : minikube ne démarre pas
```bash
# Vérifier Docker
sudo systemctl status docker

# Vérifier les logs
minikube logs

# Supprimer et recréer
minikube delete
minikube start --driver=docker --force
```

### Problème : Impossible de se connecter au service
```bash
# Vérifier que le service existe
kubectl get services

# Vérifier les endpoints
kubectl get endpoints

# Vérifier les pods
kubectl get pods

# Utiliser port-forward comme alternative
kubectl port-forward service/nginx-demo 8080:80
```

### Problème : Permission denied avec Docker
```bash
# S'assurer d'être dans le groupe docker
sudo usermod -aG docker $USER

# Se reconnecter ou utiliser
newgrp docker
```

## Ressources complémentaires

- Documentation officielle Kubernetes : https://kubernetes.io/docs/
- Documentation minikube : https://minikube.sigs.k8s.io/docs/
- Tutoriels interactifs : https://kubernetes.io/docs/tutorials/
- Cheat sheet kubectl : https://kubernetes.io/docs/reference/kubectl/cheatsheet/

## Points clés à retenir

1. **minikube** est un outil pour exécuter Kubernetes localement
2. **kubectl** est l'outil en ligne de commande pour interagir avec Kubernetes
3. Un **Deployment** gère les réplicas de vos pods
4. Un **Service** expose vos pods au réseau
5. Les fichiers **YAML** permettent de définir l'infrastructure as code
6. Le scaling est simple avec la commande `kubectl scale`
7. Les rollouts permettent des mises à jour sans interruption
