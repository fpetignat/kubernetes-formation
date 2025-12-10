# Guide d'installation Kubernetes sur Windows

Ce guide vous permet de suivre la formation Kubernetes sur une machine Windows. Deux approches sont disponibles :

- **Option A : Minikube** (recommandé pour débuter) - Solution simple et rapide
- **Option B : kubeadm sur WSL2** (pour environnement proche de la production)

## Table des matières

1. [Prérequis Windows](#prérequis-windows)
2. [Option A : Installation avec Minikube](#option-a--installation-avec-minikube)
   - [Méthode 1 : Minikube avec Docker Desktop](#méthode-1--minikube-avec-docker-desktop-recommandé)
   - [Méthode 2 : Minikube avec Hyper-V](#méthode-2--minikube-avec-hyper-v)
   - [Méthode 3 : Minikube avec VirtualBox](#méthode-3--minikube-avec-virtualbox)
3. [Option B : Installation avec kubeadm sur WSL2](#option-b--installation-avec-kubeadm-sur-wsl2)
4. [Vérification de l'installation](#vérification-de-linstallation)
5. [Commandes équivalentes pour Windows](#commandes-équivalentes-pour-windows)
6. [Troubleshooting](#troubleshooting)

---

## Prérequis Windows

### Configuration matérielle minimale

- **Processeur :** 64-bit avec support de virtualisation (Intel VT-x ou AMD-V)
- **RAM :** 4 Go minimum (8 Go recommandé)
- **Disque :** 20 Go d'espace libre
- **OS :** Windows 10/11 Professionnel, Entreprise ou Éducation (pour Hyper-V)

### Configuration logicielle

- Windows 10 version 1903 ou supérieure (pour WSL2)
- Droits administrateur sur la machine
- Connexion Internet stable

### Activation de la virtualisation

Vérifiez que la virtualisation est activée :

1. Ouvrir le **Gestionnaire des tâches** (Ctrl + Shift + Échap)
2. Onglet **Performance** → **CPU**
3. Vérifier que **Virtualisation : Activé**

Si désactivé, activer dans le BIOS/UEFI :
- Redémarrer et accéder au BIOS (généralement F2, F10, ou Suppr au démarrage)
- Chercher **Intel VT-x** ou **AMD-V** et l'activer
- Sauvegarder et redémarrer

---

## Option A : Installation avec Minikube

Minikube est la solution la plus simple pour commencer avec Kubernetes sur Windows. Il peut utiliser différents drivers (Docker Desktop, Hyper-V, VirtualBox).

### Méthode 1 : Minikube avec Docker Desktop (Recommandé)

C'est l'option **la plus simple et la plus stable** pour Windows.

#### 1.1 Installation de Docker Desktop

1. **Télécharger Docker Desktop**
   - Aller sur https://www.docker.com/products/docker-desktop
   - Télécharger Docker Desktop pour Windows
   - Exécuter l'installateur

2. **Configurer Docker Desktop**
   - Lancer Docker Desktop
   - Aller dans **Settings** → **General**
   - Cocher **Use the WSL 2 based engine** (si disponible)
   - Aller dans **Resources** → **Advanced**
   - Allouer au moins :
     - **CPUs :** 2 minimum (4 recommandé)
     - **Memory :** 4 GB minimum (8 GB recommandé)
   - Cliquer **Apply & Restart**

3. **Vérifier Docker**
   ```powershell
   # Ouvrir PowerShell en tant qu'administrateur
   docker --version
   docker run hello-world
   ```

#### 1.2 Installation de kubectl

**Option A : Via Chocolatey (recommandé)**

```powershell
# Installer Chocolatey si ce n'est pas déjà fait
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Installer kubectl
choco install kubernetes-cli -y

# Vérifier l'installation
kubectl version --client
```

**Option B : Téléchargement manuel**

```powershell
# Télécharger kubectl
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# Créer le dossier pour les binaires
New-Item -ItemType Directory -Force -Path "$HOME\bin"

# Déplacer kubectl
Move-Item -Path .\kubectl.exe -Destination "$HOME\bin\kubectl.exe"

# Ajouter au PATH (permanant)
$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('Path', "$oldPath;$HOME\bin", [EnvironmentVariableTarget]::User)

# Redémarrer PowerShell et vérifier
kubectl version --client
```

#### 1.3 Installation de Minikube

**Option A : Via Chocolatey**

```powershell
choco install minikube -y
```

**Option B : Installation manuelle**

```powershell
# Télécharger Minikube
New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing

# Ajouter au PATH
$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('Path', "$oldPath;c:\minikube", [EnvironmentVariableTarget]::User)

# Redémarrer PowerShell et vérifier
minikube version
```

#### 1.4 Démarrage de Minikube avec Docker

```powershell
# Démarrer Minikube avec le driver Docker
minikube start --driver=docker

# Optionnel : définir Docker comme driver par défaut
minikube config set driver docker

# Vérifier le statut
minikube status

# Vérifier les nodes
kubectl get nodes
```

---

### Méthode 2 : Minikube avec Hyper-V

**Prérequis :** Windows 10/11 Pro, Enterprise ou Education

#### 2.1 Activation de Hyper-V

```powershell
# Ouvrir PowerShell en tant qu'Administrateur
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Redémarrer le PC
Restart-Computer
```

#### 2.2 Installation de kubectl et Minikube

Suivre les étapes 1.2 et 1.3 de la Méthode 1.

#### 2.3 Configuration du commutateur virtuel Hyper-V

```powershell
# Ouvrir PowerShell en tant qu'Administrateur

# Créer un commutateur externe (utilise votre carte réseau)
New-VMSwitch -Name "MinikubeSwitch" -NetAdapterName "Ethernet" -AllowManagementOS $true

# Ou créer un commutateur interne
New-VMSwitch -Name "MinikubeSwitch" -SwitchType Internal
```

#### 2.4 Démarrage de Minikube avec Hyper-V

```powershell
# Démarrer Minikube avec Hyper-V
minikube start --driver=hyperv --hyperv-virtual-switch="MinikubeSwitch"

# Définir Hyper-V comme driver par défaut (optionnel)
minikube config set driver hyperv

# Vérifier
minikube status
kubectl get nodes
```

---

### Méthode 3 : Minikube avec VirtualBox

#### 3.1 Installation de VirtualBox

1. Télécharger VirtualBox : https://www.virtualbox.org/wiki/Downloads
2. Installer VirtualBox
3. Redémarrer si demandé

#### 3.2 Installation de kubectl et Minikube

Suivre les étapes 1.2 et 1.3 de la Méthode 1.

#### 3.3 Démarrage de Minikube avec VirtualBox

```powershell
# Démarrer Minikube avec VirtualBox
minikube start --driver=virtualbox

# Définir VirtualBox comme driver par défaut (optionnel)
minikube config set driver virtualbox

# Vérifier
minikube status
kubectl get nodes
```

---

## Option B : Installation avec kubeadm sur WSL2

Cette option est plus proche d'un environnement de production Linux et permet d'utiliser kubeadm.

### Prérequis

- Windows 10 version 2004+ (Build 19041+) ou Windows 11
- WSL 2

### B.1 Installation de WSL2

#### 1. Activer WSL

```powershell
# Ouvrir PowerShell en tant qu'Administrateur

# Activer WSL
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Activer la plateforme de machine virtuelle
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Redémarrer Windows
Restart-Computer
```

#### 2. Définir WSL 2 comme version par défaut

```powershell
# Après le redémarrage, ouvrir PowerShell en tant qu'Administrateur
wsl --set-default-version 2

# Mettre à jour le noyau WSL2 si nécessaire
wsl --update
```

#### 3. Installer Ubuntu

```powershell
# Installer Ubuntu 22.04 depuis le Microsoft Store
# Ou via la ligne de commande :
wsl --install -d Ubuntu-22.04

# Lancer Ubuntu et créer un utilisateur
wsl
```

### B.2 Configuration d'Ubuntu dans WSL2

Une fois dans votre terminal Ubuntu WSL2 :

```bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer les outils de base
sudo apt install -y curl wget git vim
```

### B.3 Installation de Docker dans WSL2

```bash
# Installer les dépendances
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Ajouter la clé GPG Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Ajouter le repository Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installer Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Démarrer Docker
sudo service docker start

# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Appliquer les changements
newgrp docker

# Vérifier Docker
docker --version
docker run hello-world
```

### B.4 Installation de kubectl dans WSL2

```bash
# Télécharger kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Rendre exécutable et déplacer
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Vérifier
kubectl version --client
```

### B.5 Option 1 : Minikube dans WSL2

```bash
# Télécharger Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Installer Minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Démarrer Minikube avec Docker
minikube start --driver=docker

# Vérifier
minikube status
kubectl get nodes
```

### B.6 Option 2 : kubeadm dans WSL2

Pour installer kubeadm dans WSL2, suivre le guide complet : [KUBEADM_SETUP.md](KUBEADM_SETUP.md)

**Installation rapide :**

```bash
# Désactiver swap (dans WSL2, généralement pas nécessaire)
sudo swapoff -a

# Installer les dépendances
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Ajouter la clé GPG Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Ajouter le repository Kubernetes
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Installer kubeadm, kubelet et kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Activer kubelet
sudo systemctl enable kubelet

# Initialiser le cluster (single-node)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurer kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installer un CNI (Flannel par exemple)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Permettre le scheduling sur le master (pour single-node)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Vérifier
kubectl get nodes
```

---

## Vérification de l'installation

Quelle que soit la méthode choisie, vérifiez votre installation :

```powershell
# Vérifier la version de kubectl
kubectl version --client

# Vérifier les nodes
kubectl get nodes

# Vérifier tous les pods système
kubectl get pods -A

# Vérifier les informations du cluster
kubectl cluster-info

# (Pour Minikube) Vérifier le statut
minikube status

# (Pour Minikube) Accéder au dashboard
minikube dashboard
```

**Résultat attendu :**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   2m    v1.28.0
```

---

## Commandes équivalentes pour Windows

### Différences PowerShell vs Bash

| Opération | Linux (Bash) | Windows (PowerShell) |
|-----------|--------------|----------------------|
| Lister fichiers | `ls` | `dir` ou `Get-ChildItem` |
| Créer dossier | `mkdir` | `New-Item -ItemType Directory` |
| Afficher contenu | `cat file.txt` | `Get-Content file.txt` |
| Variable PATH | `export PATH=$PATH:/new/path` | `$env:Path += ";C:\new\path"` |
| Éditer fichier | `vim file.txt` | `notepad file.txt` |
| Effacer écran | `clear` | `cls` ou `Clear-Host` |

### Variables d'environnement

```powershell
# Temporaire (session actuelle)
$env:KUBECONFIG = "$HOME\.kube\config"

# Permanent (utilisateur)
[Environment]::SetEnvironmentVariable('KUBECONFIG', "$HOME\.kube\config", [EnvironmentVariableTarget]::User)

# Afficher une variable
$env:KUBECONFIG
```

### Chemins de fichiers

```powershell
# Windows utilise des backslashes
C:\Users\username\.kube\config

# Mais accepte aussi des forward slashes
C:/Users/username/.kube/config

# Dans PowerShell, utilisez $HOME pour le répertoire utilisateur
$HOME\.kube\config
```

### Scripts

Pour les scripts Bash des TPs, vous avez deux options :

1. **Utiliser WSL2** et exécuter les scripts directement
2. **Adapter en PowerShell** (quelques modifications nécessaires)

**Exemple : Script Bash → PowerShell**

Bash :
```bash
#!/bin/bash
kubectl apply -f deployment.yaml
kubectl get pods
```

PowerShell :
```powershell
# PowerShell
kubectl apply -f deployment.yaml
kubectl get pods
```

---

## Commandes Minikube utiles pour Windows

### Gestion du cluster

```powershell
# Démarrer Minikube
minikube start

# Démarrer avec plus de ressources
minikube start --cpus=4 --memory=8192 --disk-size=40g

# Arrêter Minikube
minikube stop

# Supprimer le cluster
minikube delete

# Voir le statut
minikube status

# Voir les logs
minikube logs
```

### Accès aux services

```powershell
# Obtenir l'IP de Minikube
minikube ip

# Accéder à un service NodePort dans le navigateur
minikube service <service-name>

# Obtenir l'URL d'un service
minikube service <service-name> --url

# Ouvrir le dashboard Kubernetes
minikube dashboard
```

### Addons

```powershell
# Lister les addons disponibles
minikube addons list

# Activer un addon (ex: metrics-server)
minikube addons enable metrics-server

# Activer le dashboard
minikube addons enable dashboard

# Désactiver un addon
minikube addons disable <addon-name>
```

### Docker avec Minikube

```powershell
# Utiliser le daemon Docker de Minikube
minikube docker-env | Invoke-Expression

# Retour au Docker local
Remove-Item Env:\DOCKER_TLS_VERIFY
Remove-Item Env:\DOCKER_HOST
Remove-Item Env:\DOCKER_CERT_PATH
Remove-Item Env:\MINIKUBE_ACTIVE_DOCKERD
```

---

## Troubleshooting

### Problème : Virtualisation non disponible

**Symptôme :**
```
Error: VBoxManage not found. Make sure VirtualBox is installed
```

**Solution :**
- Vérifier que la virtualisation est activée dans le BIOS
- Installer le driver approprié (Docker Desktop, Hyper-V, ou VirtualBox)

---

### Problème : Minikube ne démarre pas

**Symptôme :**
```
Error: Failed to start minikube
```

**Solutions :**

1. **Supprimer et recréer le cluster**
   ```powershell
   minikube delete
   minikube start --driver=docker
   ```

2. **Vérifier les logs**
   ```powershell
   minikube logs
   ```

3. **Essayer un autre driver**
   ```powershell
   minikube start --driver=hyperv
   # ou
   minikube start --driver=virtualbox
   ```

---

### Problème : Docker Desktop ne fonctionne pas

**Symptôme :**
```
Error: Cannot connect to Docker daemon
```

**Solutions :**

1. **Redémarrer Docker Desktop**
   - Clic droit sur l'icône Docker dans la barre d'état
   - Sélectionner "Restart"

2. **Vérifier que WSL 2 est activé**
   ```powershell
   wsl --set-default-version 2
   ```

3. **Réinstaller Docker Desktop**

---

### Problème : kubectl ne se connecte pas au cluster

**Symptôme :**
```
The connection to the server localhost:8080 was refused
```

**Solution :**

```powershell
# Vérifier que Minikube tourne
minikube status

# Reconfigurer kubectl
minikube update-context

# Vérifier le fichier config
kubectl config view
kubectl config current-context
```

---

### Problème : Ports déjà utilisés

**Symptôme :**
```
Error: Port 8443 is already in use
```

**Solutions :**

1. **Trouver et arrêter le processus**
   ```powershell
   # Trouver le processus utilisant le port 8443
   netstat -ano | findstr :8443

   # Arrêter le processus (remplacer PID par l'ID du processus)
   taskkill /PID <PID> /F
   ```

2. **Utiliser un port différent**
   ```powershell
   minikube start --driver=docker --apiserver-port=8444
   ```

---

### Problème : Manque d'espace disque

**Symptôme :**
```
Error: No space left on device
```

**Solutions :**

1. **Nettoyer Docker**
   ```powershell
   docker system prune -a
   ```

2. **Supprimer les anciennes images**
   ```powershell
   docker images
   docker rmi <image-id>
   ```

3. **Augmenter la taille du disque Minikube**
   ```powershell
   minikube delete
   minikube start --disk-size=40g
   ```

---

### Problème : WSL2 est lent

**Solutions :**

1. **Limiter la mémoire WSL2**

   Créer/éditer le fichier `C:\Users\<username>\.wslconfig` :
   ```ini
   [wsl2]
   memory=4GB
   processors=2
   swap=0
   ```

2. **Redémarrer WSL2**
   ```powershell
   wsl --shutdown
   wsl
   ```

---

### Problème : Permission denied sur WSL2

**Symptôme :**
```
permission denied while trying to connect to Docker daemon
```

**Solution :**
```bash
# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Se reconnecter ou utiliser
newgrp docker
```

---

## Différences avec la formation AlmaLinux

### Chemins de fichiers

- **Linux :** `/home/user/.kube/config`
- **Windows :** `C:\Users\username\.kube\config` ou `$HOME\.kube\config`
- **WSL2 :** `/home/username/.kube/config` (comme Linux)

### Éditeurs de texte

- **Linux :** `vim`, `nano`
- **Windows :** `notepad`, `code` (VS Code), `notepad++`

### Commandes réseau

| Fonctionnalité | Linux | Windows PowerShell |
|----------------|-------|-------------------|
| Ping | `ping` | `ping` ou `Test-Connection` |
| IP config | `ifconfig` ou `ip addr` | `ipconfig` |
| DNS lookup | `nslookup` | `nslookup` ou `Resolve-DnsName` |
| Port scan | `netstat` | `netstat` ou `Get-NetTCPConnection` |
| Curl | `curl` | `curl` ou `Invoke-WebRequest` |

---

## Conseils pour suivre les TPs sur Windows

### 1. Choisir le bon terminal

**Recommandations :**
- **Windows Terminal** (recommandé) : moderne et supporte PowerShell, CMD, WSL
- **PowerShell 7** : version moderne de PowerShell
- **VS Code avec terminal intégré** : excellent pour le développement

### 2. Utiliser des alias PowerShell

Créer un profil PowerShell pour faciliter l'utilisation :

```powershell
# Ouvrir le profil PowerShell
notepad $PROFILE

# Ajouter des alias
Set-Alias k kubectl
Set-Alias mk minikube

# Sauvegarder et recharger
. $PROFILE
```

### 3. Activer l'auto-complétion kubectl

```powershell
# Ajouter au profil PowerShell ($PROFILE)
kubectl completion powershell | Out-String | Invoke-Expression
```

### 4. Utiliser WSL2 pour une expérience proche de Linux

Si vous voulez une expérience 100% identique aux TPs :
1. Installer WSL2 avec Ubuntu
2. Suivre les instructions Linux directement dans Ubuntu
3. Installer Minikube ou kubeadm dans WSL2

### 5. Installer Git Bash (optionnel)

Git Bash fournit un environnement Bash sur Windows :
- Télécharger depuis https://git-scm.com/downloads
- Utiliser les commandes Linux directement

---

## Ressources supplémentaires

### Documentation officielle

- [Minikube sur Windows](https://minikube.sigs.k8s.io/docs/start/)
- [Docker Desktop Documentation](https://docs.docker.com/desktop/windows/)
- [WSL2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [kubectl sur Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)

### Outils utiles pour Windows

- **Lens** : IDE Kubernetes multiplateforme (https://k8slens.dev/)
- **k9s** : Terminal UI pour Kubernetes (https://k9scli.io/)
- **Helm** : Gestionnaire de packages Kubernetes (https://helm.sh/)
- **Chocolatey** : Gestionnaire de packages Windows (https://chocolatey.org/)

### Communautés et support

- [Kubernetes Slack](https://slack.k8s.io/)
- [Minikube GitHub Issues](https://github.com/kubernetes/minikube/issues)
- [Docker Community Forums](https://forums.docker.com/)

---

## Prochaines étapes

Maintenant que votre environnement est installé :

1. ✅ Vérifier que tout fonctionne avec `kubectl get nodes`
2. 📚 Commencer le [TP1](../tp1/README.md) - Premier déploiement Kubernetes
3. 🎯 Suivre les TPs dans l'ordre recommandé
4. 💡 Consulter ce guide pour les spécificités Windows

**Bon apprentissage Kubernetes sur Windows !** 🚀
