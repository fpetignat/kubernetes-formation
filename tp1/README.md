# TP1 - Premier déploiement Kubernetes sur AlmaLinux avec Minikube

## Objectifs du TP

À la fin de ce TP, vous serez capable de :
- Installer et configurer minikube sur AlmaLinux
- Démarrer un cluster Kubernetes local
- Déployer votre première application
- Exposer l'application via un service
- Interagir avec les pods et services

## Prérequis

- Une machine AlmaLinux (physique ou virtuelle)
- 2 CPU minimum
- 2 Go de RAM minimum
- 20 Go d'espace disque
- Accès root ou sudo

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

### 1.4 Installation de minikube

```bash
# Télécharger minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Installer minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Vérifier l'installation
minikube version
```

## Partie 2 : Démarrage du cluster Kubernetes

### 2.1 Démarrer minikube

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

### 2.2 Vérifier le cluster

```bash
# Afficher les informations du cluster
kubectl cluster-info

# Lister les nœuds
kubectl get nodes

# Afficher plus de détails sur le nœud
kubectl describe node minikube
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

```bash
# Accéder au service
curl http://$(minikube ip):30080
```

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

```bash
# Voir toutes les ressources dans le namespace par défaut
kubectl get all

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

### 8.3 Arrêter et supprimer le cluster

```bash
# Arrêter minikube
minikube stop

# Supprimer le cluster
minikube delete

# Démarrer à nouveau
minikube start
```

## Exercices pratiques

### Exercice 1 : Déploiement Redis
1. Déployer une instance Redis avec l'image `redis:7-alpine`
2. L'exposer via un service de type **ClusterIP** sur le port 6379
3. Vérifier que le pod est en cours d'exécution

**Pourquoi ClusterIP ?** Redis est typiquement une base de données backend qui doit être accessible uniquement depuis l'intérieur du cluster par d'autres applications. Il n'a pas besoin d'être exposé à l'extérieur. Voir Partie 4.1 pour plus de détails sur ClusterIP.

### Exercice 2 : Application multi-conteneurs
1. Créer un déploiement avec 3 réplicas d'nginx
2. Créer un service **LoadBalancer** (qui sera converti en NodePort par minikube)
3. Tester l'accès à l'application
4. Scaler à 5 réplicas
5. Observer la distribution des pods

**À propos de LoadBalancer :** Dans un environnement de production cloud (AWS, GCP, Azure), un service LoadBalancer créerait automatiquement un load balancer externe avec une IP publique. Cependant, puisque minikube est un cluster local, il convertit automatiquement ce type en NodePort. Pour simuler un vrai LoadBalancer localement, vous pouvez utiliser `minikube tunnel` dans un terminal séparé. Voir Partie 4.1 pour plus d'informations.

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
