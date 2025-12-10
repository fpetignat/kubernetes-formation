# TP1 - Premier déploiement Kubernetes sur Windows

Ce document complète le [TP1 principal](README.md) avec des instructions spécifiques pour Windows.

## 📋 Avant de commencer

Assurez-vous d'avoir suivi le **[Guide d'installation Windows](../docs/WINDOWS_SETUP.md)** avant de commencer ce TP.

Vous devez avoir installé :
- ✅ kubectl
- ✅ Minikube (ou kubeadm sur WSL2)
- ✅ Docker Desktop ou un driver de virtualisation (Hyper-V/VirtualBox)

## 🎯 Objectifs du TP (identiques sur Windows)

À la fin de ce TP, vous serez capable de :
- Démarrer un cluster Kubernetes sur Windows
- Déployer votre première application
- Exposer l'application via un service
- Interagir avec les pods et services
- Effectuer des mises à jour et des rollbacks

---

## Partie 1 : Démarrage du cluster (Windows)

### Option A : Avec Minikube sur Windows

#### 1.1 Démarrer Minikube

**Ouvrir PowerShell en tant qu'administrateur** et exécuter :

```powershell
# Démarrer Minikube avec Docker Desktop
minikube start --driver=docker

# Ou avec Hyper-V
minikube start --driver=hyperv

# Ou avec VirtualBox
minikube start --driver=virtualbox

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

#### 1.2 Vérifier l'installation

```powershell
# Vérifier les nodes
kubectl get nodes

# Vérifier les pods système
kubectl get pods -A

# Informations du cluster
kubectl cluster-info
```

### Option B : Avec kubeadm sur WSL2

Si vous avez installé kubeadm sur WSL2, ouvrez votre terminal Ubuntu WSL2 :

```bash
# Vérifier que kubelet tourne
sudo systemctl status kubelet

# Vérifier les nodes
kubectl get nodes

# Si le node est NotReady, vérifier le CNI
kubectl get pods -n kube-system
```

---

## Partie 2 : Premier déploiement

### 2.1 Créer un déploiement NGINX

```powershell
# Créer le déploiement
kubectl create deployment nginx --image=nginx:latest

# Vérifier le déploiement
kubectl get deployments

# Voir les pods créés
kubectl get pods
```

### 2.2 Exposer le déploiement

```powershell
# Exposer via NodePort
kubectl expose deployment nginx --type=NodePort --port=80

# Voir le service
kubectl get services
```

### 2.3 Accéder à l'application (spécifique Windows)

**Avec Minikube :**

```powershell
# Option 1 : Ouvrir automatiquement dans le navigateur
minikube service nginx

# Option 2 : Obtenir l'URL
minikube service nginx --url

# Option 3 : Utiliser port-forward
kubectl port-forward service/nginx 8080:80
# Puis ouvrir http://localhost:8080 dans votre navigateur
```

**Avec kubeadm sur WSL2 :**

```bash
# Obtenir le port NodePort
kubectl get svc nginx

# Accéder via localhost:<NodePort>
# Par exemple : http://localhost:30123
```

**Tester avec PowerShell :**
```powershell
# Obtenir l'URL
$url = minikube service nginx --url

# Tester avec Invoke-WebRequest
Invoke-WebRequest -Uri $url
```

---

## Partie 3 : Gestion des déploiements

### 3.1 Scaling (identique sur toutes les plateformes)

```powershell
# Scaler à 3 réplicas
kubectl scale deployment nginx --replicas=3

# Vérifier
kubectl get pods -o wide

# Voir les détails
kubectl describe deployment nginx
```

### 3.2 Mise à jour (Rolling Update)

```powershell
# Mettre à jour l'image
kubectl set image deployment/nginx nginx=nginx:1.24

# Suivre le rollout
kubectl rollout status deployment/nginx

# Voir l'historique
kubectl rollout history deployment/nginx
```

### 3.3 Rollback

```powershell
# Revenir à la version précédente
kubectl rollout undo deployment/nginx

# Voir le statut
kubectl rollout status deployment/nginx
```

---

## Partie 4 : Utilisation de fichiers YAML

### 4.1 Créer le fichier de déploiement

**Créer le fichier avec notepad ou VS Code :**

```powershell
# Avec notepad
notepad nginx-deployment.yaml

# Ou avec VS Code
code nginx-deployment.yaml
```

**Contenu du fichier `nginx-deployment.yaml` :**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

### 4.2 Créer le fichier de service

**Créer `nginx-service.yaml` :**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
```

### 4.3 Déployer avec les fichiers YAML

```powershell
# Appliquer le déploiement
kubectl apply -f nginx-deployment.yaml

# Appliquer le service
kubectl apply -f nginx-service.yaml

# Vérifier
kubectl get all

# Accéder au service (Minikube)
minikube service nginx-service

# Ou avec port-forward
kubectl port-forward service/nginx-service 8080:80
```

---

## Partie 5 : Commandes de debugging

### 5.1 Voir les logs

```powershell
# Obtenir le nom d'un pod
kubectl get pods

# Voir les logs
kubectl logs <nom-du-pod>

# Suivre les logs en temps réel
kubectl logs -f <nom-du-pod>

# Logs de tous les pods d'un déploiement
kubectl logs -l app=nginx
```

### 5.2 Exécuter des commandes dans un pod

```powershell
# Se connecter à un pod
kubectl exec -it <nom-du-pod> -- /bin/bash

# Exécuter une commande simple
kubectl exec <nom-du-pod> -- ls -la

# Exemple : vérifier la version NGINX
kubectl exec <nom-du-pod> -- nginx -v
```

### 5.3 Informations détaillées

```powershell
# Détails d'un pod
kubectl describe pod <nom-du-pod>

# Détails d'un déploiement
kubectl describe deployment nginx-app

# Détails d'un service
kubectl describe service nginx-service

# Événements du cluster
kubectl get events --sort-by='.lastTimestamp'
```

---

## Partie 6 : Exercices pratiques

### Exercice 1 : Déployer une application web simple

**Objectif :** Déployer une application web et l'exposer

```powershell
# 1. Créer un déploiement avec l'image httpd:2.4
kubectl create deployment web-server --image=httpd:2.4

# 2. Scaler à 2 réplicas
kubectl scale deployment web-server --replicas=2

# 3. Exposer sur le port 80
kubectl expose deployment web-server --type=NodePort --port=80

# 4. Accéder au service
minikube service web-server

# 5. Nettoyer
kubectl delete deployment web-server
kubectl delete service web-server
```

### Exercice 2 : Utiliser des ConfigMaps

**Créer un fichier `configmap.yaml` :**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.name: "Mon Application"
  app.version: "1.0"
  app.environment: "development"
```

**Créer un déploiement utilisant la ConfigMap :**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-config
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:latest
        env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: app.name
        - name: APP_VERSION
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: app.version
```

**Déployer :**

```powershell
# Créer la ConfigMap
kubectl apply -f configmap.yaml

# Créer le déploiement
kubectl apply -f deployment-with-config.yaml

# Vérifier les variables d'environnement
kubectl exec <nom-du-pod> -- env | Select-String "APP_"
```

### Exercice 3 : Monitoring avec le Dashboard

**Avec Minikube :**

```powershell
# Activer l'addon dashboard
minikube addons enable dashboard

# Lancer le dashboard
minikube dashboard

# Le navigateur s'ouvre automatiquement
# Explorer : Workloads, Services, Config, Storage
```

---

## Partie 7 : Différences Windows vs Linux

### 7.1 Chemins de fichiers

```powershell
# Configuration kubectl sur Windows
$HOME\.kube\config
# ou
C:\Users\<username>\.kube\config

# Sur Linux/WSL2
~/.kube/config
# ou
/home/<username>/.kube/config
```

### 7.2 Variables d'environnement

```powershell
# Définir KUBECONFIG (temporaire)
$env:KUBECONFIG = "$HOME\.kube\custom-config"

# Définir KUBECONFIG (permanent)
[Environment]::SetEnvironmentVariable('KUBECONFIG', "$HOME\.kube\custom-config", 'User')

# Vérifier
$env:KUBECONFIG
```

### 7.3 Scripts Bash → PowerShell

**Exemple de conversion :**

Script Bash du TP1 :
```bash
#!/bin/bash
for i in {1..5}; do
  kubectl get pods
  sleep 2
done
```

Version PowerShell :
```powershell
# PowerShell
for ($i=1; $i -le 5; $i++) {
  kubectl get pods
  Start-Sleep -Seconds 2
}
```

### 7.4 Commandes équivalentes

| Tâche | Linux | Windows PowerShell |
|-------|-------|-------------------|
| Lister pods | `kubectl get pods` | `kubectl get pods` |
| Logs | `kubectl logs -f pod` | `kubectl logs -f pod` |
| Fichier texte | `cat file.yaml` | `Get-Content file.yaml` |
| Éditer | `vim file.yaml` | `notepad file.yaml` ou `code file.yaml` |
| Grep | `kubectl get pods \| grep nginx` | `kubectl get pods \| Select-String nginx` |

---

## Partie 8 : Commandes Minikube spécifiques Windows

### 8.1 Gestion du cluster

```powershell
# Démarrer avec plus de ressources
minikube start --cpus=4 --memory=8192 --disk-size=40g

# Arrêter sans supprimer
minikube stop

# Supprimer complètement
minikube delete

# Redémarrer après modification
minikube delete
minikube start --driver=docker
```

### 8.2 Addons utiles

```powershell
# Lister les addons
minikube addons list

# Activer metrics-server (pour HPA)
minikube addons enable metrics-server

# Activer le dashboard
minikube addons enable dashboard

# Activer Ingress
minikube addons enable ingress

# Vérifier les addons actifs
minikube addons list | Select-String "enabled"
```

### 8.3 Accès aux services

```powershell
# Obtenir l'IP de Minikube
minikube ip

# Lister tous les services et leurs URLs
minikube service list

# Obtenir l'URL d'un service spécifique
minikube service <service-name> --url

# Tunnel pour les services LoadBalancer
minikube tunnel
# (Laisser tourner dans une autre fenêtre PowerShell)
```

### 8.4 Docker avec Minikube

```powershell
# Utiliser le daemon Docker de Minikube
minikube docker-env | Invoke-Expression

# Construire une image directement dans Minikube
docker build -t myapp:1.0 .

# Utiliser l'image dans un déploiement
kubectl create deployment myapp --image=myapp:1.0

# Retour au Docker local
# Fermer et rouvrir PowerShell, ou :
Remove-Item Env:\DOCKER_*
```

---

## Partie 9 : Troubleshooting Windows

### Problème : Minikube ne démarre pas

```powershell
# Voir les logs
minikube logs

# Supprimer et recréer
minikube delete --all --purge
minikube start --driver=docker

# Essayer un autre driver
minikube start --driver=hyperv
```

### Problème : Docker Desktop ne répond pas

```powershell
# Redémarrer Docker Desktop via l'icône système

# Ou en ligne de commande
Stop-Service docker
Start-Service docker

# Vérifier
docker ps
```

### Problème : Kubectl ne se connecte pas

```powershell
# Vérifier le contexte
kubectl config current-context

# Lister les contextes
kubectl config get-contexts

# Basculer vers minikube
kubectl config use-context minikube

# Mettre à jour le contexte
minikube update-context
```

### Problème : Ports utilisés

```powershell
# Trouver qui utilise un port
netstat -ano | findstr :8080

# Tuer le processus (PID)
taskkill /PID <numero> /F
```

---

## Partie 10 : Astuces et bonnes pratiques Windows

### 10.1 Alias PowerShell

Créer un profil PowerShell pour gagner du temps :

```powershell
# Ouvrir/créer le profil
if (!(Test-Path -Path $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force
}
notepad $PROFILE

# Ajouter ces alias
Set-Alias -Name k -Value kubectl
Set-Alias -Name mk -Value minikube

# Fonctions utiles
function kgp { kubectl get pods $args }
function kgs { kubectl get services $args }
function kgd { kubectl get deployments $args }
function kdp { kubectl describe pod $args }
function kl { kubectl logs $args }

# Sauvegarder et recharger
. $PROFILE
```

### 10.2 Auto-complétion kubectl

```powershell
# Ajouter au profil PowerShell
kubectl completion powershell | Out-String | Invoke-Expression

# Pour la session actuelle
kubectl completion powershell | Out-String | Invoke-Expression
```

### 10.3 Utiliser Windows Terminal

Windows Terminal offre une meilleure expérience :

```powershell
# Installer via Microsoft Store ou winget
winget install Microsoft.WindowsTerminal

# Personnaliser pour Kubernetes
# Settings → Profiles → Add new
# Nom : "Kubernetes"
# Commande : powershell.exe
# Dossier de départ : %USERPROFILE%\kubernetes-formation
```

### 10.4 Intégration VS Code

VS Code est excellent pour Kubernetes :

```powershell
# Installer VS Code
winget install Microsoft.VisualStudioCode

# Extensions recommandées :
# - Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
# - YAML (redhat.vscode-yaml)
# - Docker (ms-azuretools.vscode-docker)
```

---

## Partie 11 : Nettoyage

### Nettoyage après le TP

```powershell
# Supprimer les ressources créées
kubectl delete deployment nginx nginx-app web-server
kubectl delete service nginx nginx-service web-server
kubectl delete configmap app-config

# Voir ce qui reste
kubectl get all

# Arrêter Minikube (conserver le cluster)
minikube stop

# Ou supprimer complètement le cluster
minikube delete
```

### Nettoyage complet

```powershell
# Supprimer tous les clusters Minikube
minikube delete --all

# Nettoyer Docker
docker system prune -a

# Libérer de l'espace disque
minikube delete --purge
```

---

## Prochaines étapes

Maintenant que vous avez réussi le TP1 sur Windows :

1. ✅ Vous savez démarrer un cluster Kubernetes
2. ✅ Vous pouvez déployer et exposer des applications
3. ✅ Vous maîtrisez les commandes kubectl de base
4. ✅ Vous comprenez les différences Windows/Linux

**Continuez avec :**
- 📚 [TP2 - Maîtriser les Manifests Kubernetes](../tp2/README.md)
- 💡 Consultez le [guide Windows](../docs/WINDOWS_SETUP.md) au besoin

---

## Ressources supplémentaires Windows

### Documentation

- [Minikube sur Windows](https://minikube.sigs.k8s.io/docs/start/)
- [Docker Desktop](https://docs.docker.com/desktop/windows/)
- [kubectl sur Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
- [WSL2 Documentation](https://docs.microsoft.com/windows/wsl/)

### Outils

- **Lens** : IDE Kubernetes (https://k8slens.dev/)
- **k9s** : Terminal UI pour Kubernetes (https://k9scli.io/)
- **Chocolatey** : Gestionnaire de packages (https://chocolatey.org/)

### Aide

Si vous rencontrez des problèmes spécifiques à Windows :
1. Consultez le [guide Windows complet](../docs/WINDOWS_SETUP.md)
2. Vérifiez la section [Troubleshooting](#partie-9--troubleshooting-windows)
3. Consultez les issues GitHub de Minikube

**Bon apprentissage Kubernetes sur Windows !** 🚀
