# Déploiement Kubernetes en Environnement Air-Gapped

## Introduction

Un environnement **air-gapped** (ou déconnecté) est un réseau complètement isolé d'Internet et de tout réseau externe. Ce document couvre les stratégies et techniques pour déployer et maintenir un cluster Kubernetes dans ces conditions extrêmes.

## 🔒 Qu'est-ce qu'un Environnement Air-Gapped ?

### Définition

Un environnement air-gapped présente les caractéristiques suivantes :
- ❌ **Aucun accès Internet** : Pas de connexion sortante vers le web
- ❌ **Isolation réseau** : Séparation physique ou logique totale
- ✅ **Transferts manuels** : Médias physiques uniquement (USB, DVD, etc.)
- ✅ **Sécurité maximale** : Protection contre les attaques externes

### Cas d'Usage

- **Militaire / Défense** : Systèmes de commandement et contrôle
- **Gouvernemental** : Infrastructure critique nationale
- **Industriel** : SCADA, systèmes de contrôle d'usine
- **Finance** : Systèmes de trading haute fréquence
- **Recherche** : Laboratoires sensibles

### Défis Spécifiques

| Défi | Impact | Solution |
|------|--------|----------|
| **Téléchargement d'images** | Impossible de pull depuis Docker Hub | Registre privé pré-chargé |
| **Mises à jour** | Pas d'accès aux repos Git/Helm | Synchronisation manuelle |
| **Dépendances** | Impossible d'installer packages à la volée | Bundles pré-packagés |
| **Certificats** | Pas de Let's Encrypt, ACME | PKI interne |
| **DNS externe** | Pas de résolution de noms publics | DNS interne uniquement |
| **NTP** | Pas de serveurs de temps externes | Serveurs NTP internes |

## 🏗️ Architecture Air-Gapped

### Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet                                │
│   (Docker Hub, GitHub, Helm repos, etc.)                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                     [AIR GAP]
                           │
              ┌────────────▼────────────┐
              │  Station de Transfert   │
              │  (Connected Workstation)│
              │                          │
              │  - Download images      │
              │  - Download charts      │
              │  - Download binaries    │
              │  - Create bundles       │
              └────────────┬────────────┘
                           │
                   [Physical Transfer]
                  (USB, DVD, Secure File Transfer)
                           │
              ┌────────────▼────────────┐
              │  Station d'Import       │
              │  (Air-Gapped Bastion)   │
              │                          │
              │  - Unpack bundles       │
              │  - Upload to registry   │
              │  - Validate checksums   │
              └────────────┬────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                   │
        ▼                  ▼                   ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Harbor     │  │   GitLab     │  │   Artifact   │
│  (Registry)  │  │   (Git)      │  │  Repository  │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
              ┌───────────▼───────────┐
              │                       │
              │  Kubernetes Cluster   │
              │   (Air-Gapped)        │
              │                       │
              │  ┌─────┐  ┌─────┐    │
              │  │Node1│  │Node2│    │
              │  └─────┘  └─────┘    │
              │  ┌─────┐  ┌─────┐    │
              │  │Node3│  │Node4│    │
              │  └─────┘  └─────┘    │
              │                       │
              └───────────────────────┘
```

## 📦 Préparation des Bundles

### 1. Images de Conteneurs

#### Lister toutes les images nécessaires

```bash
#!/bin/bash
# list-required-images.sh

# Images de base Kubernetes
KUBERNETES_VERSION="v1.29.0"
IMAGES=(
  # Control plane
  "registry.k8s.io/kube-apiserver:${KUBERNETES_VERSION}"
  "registry.k8s.io/kube-controller-manager:${KUBERNETES_VERSION}"
  "registry.k8s.io/kube-scheduler:${KUBERNETES_VERSION}"
  "registry.k8s.io/kube-proxy:${KUBERNETES_VERSION}"

  # Networking
  "registry.k8s.io/pause:3.9"
  "registry.k8s.io/coredns/coredns:v1.11.1"

  # CNI (Calico example)
  "docker.io/calico/cni:v3.26.0"
  "docker.io/calico/node:v3.26.0"
  "docker.io/calico/kube-controllers:v3.26.0"

  # Storage (si utilisé)
  "registry.k8s.io/sig-storage/csi-provisioner:v3.5.0"
  "registry.k8s.io/sig-storage/csi-attacher:v4.3.0"
  "registry.k8s.io/sig-storage/csi-resizer:v1.8.0"

  # Monitoring
  "quay.io/prometheus/prometheus:v2.45.0"
  "quay.io/prometheus/node-exporter:v1.6.0"
  "grafana/grafana:10.0.0"

  # Logging
  "docker.io/fluent/fluent-bit:2.1.0"

  # Ingress
  "registry.k8s.io/ingress-nginx/controller:v1.8.1"

  # Registry
  "goharbor/harbor-core:v2.9.0"
  "goharbor/harbor-portal:v2.9.0"
  "goharbor/harbor-jobservice:v2.9.0"
  "goharbor/nginx-photon:v2.9.0"
  "goharbor/harbor-registryctl:v2.9.0"
  "goharbor/registry-photon:v2.9.0"
  "goharbor/harbor-db:v2.9.0"
  "goharbor/redis-photon:v2.9.0"
  "goharbor/trivy-adapter-photon:v2.9.0"

  # Applications (à personnaliser)
  "nginx:1.25-alpine"
  "postgres:15-alpine"
  "redis:7-alpine"
)

# Exporter la liste
printf '%s\n' "${IMAGES[@]}" > images-list.txt
```

#### Télécharger et sauvegarder les images

```bash
#!/bin/bash
# download-images.sh

set -euo pipefail

IMAGES_LIST="images-list.txt"
OUTPUT_DIR="./airgap-bundle/images"
LOG_FILE="download.log"

mkdir -p "${OUTPUT_DIR}"

echo "Starting image download at $(date)" | tee -a "${LOG_FILE}"

while IFS= read -r image; do
  echo "Pulling ${image}..." | tee -a "${LOG_FILE}"

  if docker pull "${image}"; then
    # Sanitize image name for filename
    image_file=$(echo "${image}" | tr '/:' '_')

    echo "Saving ${image} to ${image_file}.tar..." | tee -a "${LOG_FILE}"
    docker save "${image}" -o "${OUTPUT_DIR}/${image_file}.tar"

    # Create checksum
    sha256sum "${OUTPUT_DIR}/${image_file}.tar" > "${OUTPUT_DIR}/${image_file}.tar.sha256"

    echo "✓ ${image} saved successfully" | tee -a "${LOG_FILE}"
  else
    echo "✗ Failed to pull ${image}" | tee -a "${LOG_FILE}"
  fi
done < "${IMAGES_LIST}"

echo "Download completed at $(date)" | tee -a "${LOG_FILE}"
```

#### Alternative : Utiliser skopeo pour efficacité

```bash
#!/bin/bash
# download-images-skopeo.sh

set -euo pipefail

IMAGES_LIST="images-list.txt"
OUTPUT_DIR="./airgap-bundle/oci-layout"

mkdir -p "${OUTPUT_DIR}"

while IFS= read -r image; do
  echo "Copying ${image}..."

  # Copier au format OCI layout (plus efficace)
  skopeo copy \
    "docker://${image}" \
    "oci:${OUTPUT_DIR}:${image}" \
    --multi-arch all

done < "${IMAGES_LIST}"
```

### 2. Binaires Kubernetes

```bash
#!/bin/bash
# download-kubernetes-binaries.sh

KUBERNETES_VERSION="v1.29.0"
OUTPUT_DIR="./airgap-bundle/binaries"

mkdir -p "${OUTPUT_DIR}"

BINARIES=(
  "kubeadm"
  "kubectl"
  "kubelet"
)

# Download Kubernetes binaries
for binary in "${BINARIES[@]}"; do
  echo "Downloading ${binary} ${KUBERNETES_VERSION}..."

  curl -L "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/${binary}" \
    -o "${OUTPUT_DIR}/${binary}"

  # Checksum
  curl -L "https://dl.k8s.io/${KUBERNETES_VERSION}/bin/linux/amd64/${binary}.sha256" \
    -o "${OUTPUT_DIR}/${binary}.sha256"

  chmod +x "${OUTPUT_DIR}/${binary}"
done

# Download etcdctl
ETCD_VERSION="v3.5.9"
echo "Downloading etcd ${ETCD_VERSION}..."

curl -L "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz" \
  -o "${OUTPUT_DIR}/etcd-${ETCD_VERSION}.tar.gz"

# Download containerd
CONTAINERD_VERSION="1.7.8"
echo "Downloading containerd ${CONTAINERD_VERSION}..."

curl -L "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz" \
  -o "${OUTPUT_DIR}/containerd-${CONTAINERD_VERSION}.tar.gz"

# Download runc
RUNC_VERSION="v1.1.9"
echo "Downloading runc ${RUNC_VERSION}..."

curl -L "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64" \
  -o "${OUTPUT_DIR}/runc"

chmod +x "${OUTPUT_DIR}/runc"

# Download CNI plugins
CNI_VERSION="v1.3.0"
echo "Downloading CNI plugins ${CNI_VERSION}..."

curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz" \
  -o "${OUTPUT_DIR}/cni-plugins-${CNI_VERSION}.tgz"

echo "All binaries downloaded to ${OUTPUT_DIR}"
```

### 3. Helm Charts

```bash
#!/bin/bash
# download-helm-charts.sh

OUTPUT_DIR="./airgap-bundle/charts"

mkdir -p "${OUTPUT_DIR}"

# Add repos
helm repo add harbor https://helm.goharbor.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Download charts
CHARTS=(
  "harbor/harbor:1.13.0"
  "prometheus-community/kube-prometheus-stack:51.0.0"
  "grafana/loki-stack:2.9.10"
  "ingress-nginx/ingress-nginx:4.8.0"
)

for chart in "${CHARTS[@]}"; do
  echo "Downloading ${chart}..."
  helm pull "${chart}" --destination "${OUTPUT_DIR}"
done

# Extract and package with all dependencies
for chart_file in "${OUTPUT_DIR}"/*.tgz; do
  chart_name=$(basename "${chart_file}" .tgz)
  echo "Processing ${chart_name}..."

  # Extract
  tar -xzf "${chart_file}" -C "${OUTPUT_DIR}"

  # Download dependencies
  helm dependency update "${OUTPUT_DIR}/${chart_name%%-[0-9]*}"

  # Re-package with dependencies
  helm package "${OUTPUT_DIR}/${chart_name%%-[0-9]*}" -d "${OUTPUT_DIR}"
done

echo "All charts downloaded to ${OUTPUT_DIR}"
```

### 4. Créer le Bundle Final

```bash
#!/bin/bash
# create-airgap-bundle.sh

set -euo pipefail

BUNDLE_VERSION="$(date +%Y%m%d-%H%M%S)"
BUNDLE_NAME="kubernetes-airgap-bundle-${BUNDLE_VERSION}"
BUNDLE_DIR="./airgap-bundle"

echo "Creating air-gap bundle: ${BUNDLE_NAME}"

# Create bundle structure
mkdir -p "${BUNDLE_NAME}"/{images,binaries,charts,manifests,scripts}

# Copy all components
cp -r "${BUNDLE_DIR}/images/"* "${BUNDLE_NAME}/images/"
cp -r "${BUNDLE_DIR}/binaries/"* "${BUNDLE_NAME}/binaries/"
cp -r "${BUNDLE_DIR}/charts/"* "${BUNDLE_NAME}/charts/"

# Copy installation scripts
cat > "${BUNDLE_NAME}/scripts/install.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$(dirname "${SCRIPT_DIR}")"

echo "Kubernetes Air-Gap Installation"
echo "================================"

# 1. Install binaries
echo "1. Installing Kubernetes binaries..."
sudo cp "${BUNDLE_DIR}/binaries/kubeadm" /usr/local/bin/
sudo cp "${BUNDLE_DIR}/binaries/kubectl" /usr/local/bin/
sudo cp "${BUNDLE_DIR}/binaries/kubelet" /usr/local/bin/
sudo chmod +x /usr/local/bin/{kubeadm,kubectl,kubelet}

# 2. Install container runtime
echo "2. Installing containerd..."
sudo tar -xzf "${BUNDLE_DIR}/binaries/containerd-"*.tar.gz -C /usr/local

# 3. Install CNI plugins
echo "3. Installing CNI plugins..."
sudo mkdir -p /opt/cni/bin
sudo tar -xzf "${BUNDLE_DIR}/binaries/cni-plugins-"*.tgz -C /opt/cni/bin

# 4. Load images
echo "4. Loading container images..."
for image_tar in "${BUNDLE_DIR}/images/"*.tar; do
  echo "Loading $(basename "${image_tar}")..."
  sudo ctr -n k8s.io images import "${image_tar}"
done

echo "Installation completed!"
EOF

chmod +x "${BUNDLE_NAME}/scripts/install.sh"

# Create manifest with bundle info
cat > "${BUNDLE_NAME}/MANIFEST.txt" <<EOF
Kubernetes Air-Gap Bundle
=========================

Version: ${BUNDLE_VERSION}
Created: $(date)
Kubernetes Version: v1.29.0

Contents:
---------
- Kubernetes binaries (kubeadm, kubectl, kubelet)
- Container runtime (containerd)
- CNI plugins
- Container images (see images/ directory)
- Helm charts (see charts/ directory)
- Installation scripts (see scripts/ directory)

Installation:
-------------
1. Transfer this bundle to the air-gapped environment
2. Extract the bundle: tar -xzf ${BUNDLE_NAME}.tar.gz
3. Run: cd ${BUNDLE_NAME} && sudo ./scripts/install.sh
4. Initialize cluster: sudo kubeadm init --config=manifests/kubeadm-config.yaml

For detailed instructions, see README.md
EOF

# Create checksums
echo "Generating checksums..."
find "${BUNDLE_NAME}" -type f -exec sha256sum {} \; > "${BUNDLE_NAME}/SHA256SUMS.txt"

# Compress bundle
echo "Compressing bundle..."
tar -czf "${BUNDLE_NAME}.tar.gz" "${BUNDLE_NAME}"

# Final checksum
sha256sum "${BUNDLE_NAME}.tar.gz" > "${BUNDLE_NAME}.tar.gz.sha256"

BUNDLE_SIZE=$(du -h "${BUNDLE_NAME}.tar.gz" | cut -f1)
echo ""
echo "✓ Bundle created successfully!"
echo "  File: ${BUNDLE_NAME}.tar.gz"
echo "  Size: ${BUNDLE_SIZE}"
echo "  Checksum: $(cat "${BUNDLE_NAME}.tar.gz.sha256")"
```

## 🚀 Installation en Air-Gapped

### 1. Transfert du Bundle

```bash
# Sur la station de transfert (connectée)
# Copier le bundle sur média physique ou transfert sécurisé
cp kubernetes-airgap-bundle-*.tar.gz /media/usb/

# Sur la station air-gapped
# Vérifier le checksum
sha256sum -c kubernetes-airgap-bundle-*.tar.gz.sha256

# Extraire
tar -xzf kubernetes-airgap-bundle-*.tar.gz
cd kubernetes-airgap-bundle-*/
```

### 2. Installation des Composants

#### Installation Binaries

```bash
# Exécuter le script d'installation
sudo ./scripts/install.sh

# Vérifier
kubeadm version
kubectl version --client
```

#### Configuration Kubeadm pour Air-Gap

```yaml
# manifests/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.1.10
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: Never  # Important : Never pull from internet

---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.29.0
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
controlPlaneEndpoint: "k8s-api.internal.company.com:6443"

# DNS interne
dns:
  imageRepository: registry.k8s.io/coredns
  imageTag: v1.11.1

# Utiliser registre local si disponible
imageRepository: harbor.internal.company.com/kubernetes

# Certificats avec durée longue
certificatesDir: /etc/kubernetes/pki
apiServer:
  certSANs:
    - "k8s-api.internal.company.com"
    - "192.168.1.10"
  extraArgs:
    # Désactiver admission plugins qui nécessitent Internet
    enable-admission-plugins: "NodeRestriction,PodSecurityPolicy"

# etcd
etcd:
  local:
    dataDir: /var/lib/etcd
    extraArgs:
      listen-metrics-urls: http://0.0.0.0:2381
```

#### Initialisation du Cluster

```bash
# Initialiser le master node
sudo kubeadm init \
  --config manifests/kubeadm-config.yaml \
  --upload-certs \
  --ignore-preflight-errors=ImagePull

# Configurer kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Vérifier
kubectl get nodes
kubectl get pods -A
```

### 3. Déploiement du CNI (Calico Air-Gapped)

```yaml
# calico-airgap.yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Images pré-chargées localement
  registry: harbor.internal.company.com/calico
  imagePath: calico
  imagePullSecrets:
    - name: harbor-registry-secret

  # Configuration réseau
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: all()

  # Désactiver les fonctionnalités nécessitant Internet
  variant: Calico

  # Node configuration
  nodeUpdateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
```

```bash
# Appliquer Calico
kubectl apply -f calico-airgap.yaml

# Attendre que tous les pods soient ready
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n calico-system --timeout=300s
```

### 4. Déploiement du Registre Harbor

```bash
# Charger les images Harbor
for image in images/goharbor_*.tar; do
  echo "Loading $(basename "$image")..."
  sudo ctr -n k8s.io images import "$image"
done

# Installer Harbor avec Helm
helm install harbor ./charts/harbor-*.tgz \
  --namespace harbor \
  --create-namespace \
  -f - <<EOF
expose:
  type: nodePort
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
      notarySecretName: notary-tls

externalURL: https://harbor.internal.company.com:30003

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      size: 500Gi
    database:
      size: 10Gi

# Important pour air-gap
trivy:
  enabled: true
  skipUpdate: true  # Ne pas mettre à jour la DB depuis Internet

# Disable features requiring Internet
notary:
  enabled: false

chartmuseum:
  enabled: true
EOF
```

### 5. Charger les Images dans Harbor

```bash
#!/bin/bash
# upload-images-to-harbor.sh

HARBOR_URL="harbor.internal.company.com"
HARBOR_PROJECT="kubernetes"
HARBOR_USER="admin"
HARBOR_PASSWORD="Harbor12345"

# Login to Harbor
echo "${HARBOR_PASSWORD}" | docker login "${HARBOR_URL}" -u "${HARBOR_USER}" --password-stdin

# Load and push all images
for image_tar in images/*.tar; do
  echo "Processing $(basename "${image_tar}")..."

  # Load image
  docker load -i "${image_tar}"

  # Get image name
  IMAGE_NAME=$(docker load -i "${image_tar}" | grep -oP 'Loaded image: \K.*')

  # Tag for Harbor
  NEW_IMAGE_NAME="${HARBOR_URL}/${HARBOR_PROJECT}/$(echo "${IMAGE_NAME}" | sed 's|.*/||')"
  docker tag "${IMAGE_NAME}" "${NEW_IMAGE_NAME}"

  # Push to Harbor
  docker push "${NEW_IMAGE_NAME}"

  echo "✓ ${IMAGE_NAME} uploaded to Harbor"
done

echo "All images uploaded successfully!"
```

## 🔄 Maintenir un Environnement Air-Gapped

### Processus de Mise à Jour

```
┌──────────────────────────────────────────────┐
│  1. CONNECTED ENVIRONMENT                    │
│     - Download new images                    │
│     - Download new charts                    │
│     - Download security patches              │
│     - Test updates                           │
│     - Create update bundle                   │
└──────────────┬───────────────────────────────┘
               │
         [Transfer Medium]
               │
┌──────────────▼───────────────────────────────┐
│  2. AIR-GAPPED ENVIRONMENT                   │
│     - Verify checksums                       │
│     - Import to staging                      │
│     - Test in staging cluster                │
│     - Promote to production                  │
└──────────────────────────────────────────────┘
```

#### Script de Création d'Update Bundle

```bash
#!/bin/bash
# create-update-bundle.sh

set -euo pipefail

PREVIOUS_VERSION="20240115"
NEW_VERSION="$(date +%Y%m%d)"
BUNDLE_NAME="kubernetes-update-${PREVIOUS_VERSION}-to-${NEW_VERSION}"

mkdir -p "${BUNDLE_NAME}"/{images,charts,patches}

# Compare and download only new/updated images
comm -13 \
  <(cat "bundles/bundle-${PREVIOUS_VERSION}/images-list.txt" | sort) \
  <(cat images-list.txt | sort) \
  > "${BUNDLE_NAME}/new-images.txt"

# Download new images
while IFS= read -r image; do
  docker pull "${image}"
  image_file=$(echo "${image}" | tr '/:' '_')
  docker save "${image}" -o "${BUNDLE_NAME}/images/${image_file}.tar"
done < "${BUNDLE_NAME}/new-images.txt"

# Include update instructions
cat > "${BUNDLE_NAME}/UPDATE_INSTRUCTIONS.md" <<EOF
# Update Instructions

## From: ${PREVIOUS_VERSION}
## To: ${NEW_VERSION}

### Changes:
- Updated Kubernetes to v1.29.1
- Security patches for CVE-2024-XXXX
- New monitoring stack version

### Steps:
1. Verify current version
2. Backup etcd
3. Import new images to Harbor
4. Update manifests via GitOps
5. Rolling update nodes
6. Verify cluster health

### Rollback:
Keep previous bundle for 30 days to allow rollback.
EOF

# Create bundle
tar -czf "${BUNDLE_NAME}.tar.gz" "${BUNDLE_NAME}"
sha256sum "${BUNDLE_NAME}.tar.gz" > "${BUNDLE_NAME}.tar.gz.sha256"

echo "Update bundle created: ${BUNDLE_NAME}.tar.gz"
```

### Gestion des CVE et Patches de Sécurité

```bash
#!/bin/bash
# security-update-check.sh

# Sur système connecté
# Vérifier les CVE pour les images utilisées

IMAGES_FILE="images-list.txt"
REPORT_FILE="security-report-$(date +%Y%m%d).html"

# Scanner avec Trivy
while IFS= read -r image; do
  echo "Scanning ${image}..."

  trivy image \
    --severity CRITICAL,HIGH \
    --format template \
    --template '@contrib/html.tpl' \
    -o "scan-${image//\//_}.html" \
    "${image}"

done < "${IMAGES_FILE}"

# Consolider les rapports
echo "<html><body><h1>Security Scan Report - $(date)</h1>" > "${REPORT_FILE}"

for scan_file in scan-*.html; do
  cat "${scan_file}" >> "${REPORT_FILE}"
done

echo "</body></html>" >> "${REPORT_FILE}"

echo "Security report generated: ${REPORT_FILE}"
echo "Transfer this report to air-gapped environment for review"
```

## 🛠️ Outils pour Air-Gap

### 1. Airgapper (Replicated)

Outil commercial pour gérer des déploiements air-gapped.

```bash
# Installation sur système connecté
curl -sSL https://get.replicated.com/airgap | sudo bash

# Créer un bundle
airgapper bundle create \
  --name myapp \
  --namespace production \
  --version v1.2.0 \
  --output myapp-v1.2.0.airgap

# Transfert et installation sur air-gapped
airgapper bundle install myapp-v1.2.0.airgap
```

### 2. Hauler (Rancher)

Outil open-source pour créer des bundles air-gapped.

```bash
# Installation
wget https://github.com/rancherfederal/hauler/releases/download/v1.0.0/hauler_1.0.0_linux_amd64.tar.gz
tar -xzf hauler_1.0.0_linux_amd64.tar.gz
sudo mv hauler /usr/local/bin/

# Créer un manifest
cat > hauler-manifest.yaml <<EOF
apiVersion: content.hauler.cattle.io/v1alpha1
kind: Images
metadata:
  name: kubernetes-images
spec:
  images:
    - name: registry.k8s.io/kube-apiserver:v1.29.0
    - name: registry.k8s.io/kube-controller-manager:v1.29.0
    - name: registry.k8s.io/kube-scheduler:v1.29.0
    - name: quay.io/prometheus/prometheus:v2.45.0
EOF

# Fetch content
hauler store sync -f hauler-manifest.yaml

# Create bundle
hauler store save --filename kubernetes-airgap.tar.zst

# Transfer and load on air-gapped system
hauler store load kubernetes-airgap.tar.zst
hauler store serve registry
```

### 3. Carvel (VMware)

Suite d'outils incluant imgpkg pour bundles d'images.

```bash
# Installation
wget -O- https://carvel.dev/install.sh | bash

# Créer un bundle
imgpkg push -b harbor.internal.company.com/bundles/myapp:v1.0.0 \
  -f manifests/ \
  --lock-output /tmp/bundle.lock.yml

# Copier le bundle
imgpkg copy \
  -b harbor.internal.company.com/bundles/myapp:v1.0.0 \
  --to-tar myapp-v1.0.0.tar

# Sur air-gapped, charger le bundle
imgpkg copy \
  --tar myapp-v1.0.0.tar \
  --to-repo harbor-airgap.internal/bundles/myapp

# Déployer
imgpkg pull \
  -b harbor-airgap.internal/bundles/myapp:v1.0.0 \
  -o /tmp/myapp

kubectl apply -f /tmp/myapp/manifests/
```

## 📊 Monitoring en Air-Gap

### Prometheus sans Accès Internet

```yaml
# prometheus-values-airgap.yaml
prometheus:
  prometheusSpec:
    image:
      registry: harbor.internal.company.com/monitoring
      repository: prometheus
      tag: v2.45.0

    # Pas de scraping de endpoints externes
    externalLabels:
      cluster: "production-airgap"

    # Stockage local uniquement
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 500Gi

    # Désactiver les features nécessitant Internet
    retention: 90d
    retentionSize: "450GB"

# Désactiver le téléchargement de règles depuis Internet
prometheusOperator:
  image:
    registry: harbor.internal.company.com/monitoring
    repository: prometheus-operator

  # Pas de mise à jour automatique de CRDs
  manageCrds: false

# Grafana avec dashboards pré-chargés
grafana:
  image:
    registry: harbor.internal.company.com/monitoring
    repository: grafana

  # Dashboards embarqués dans ConfigMaps
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

  # Pas de plugin downloads
  plugins: []
```

### AlertManager Configuration

```yaml
# alertmanager-config.yaml
global:
  # Pas de résolution DNS externe
  resolve_timeout: 5m

# Routes internes uniquement
route:
  receiver: 'team-email'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
- name: 'team-email'
  email_configs:
  - to: 'ops@internal.company.com'
    from: 'alertmanager@internal.company.com'
    smarthost: 'smtp.internal.company.com:25'
    # Serveur SMTP interne uniquement
    require_tls: true

- name: 'webhook'
  webhook_configs:
  - url: 'http://alertmanager-webhook.monitoring.svc.cluster.local:8080/alerts'
    # Webhook interne seulement
```

## 🔐 Sécurité Avancée Air-Gap

### PKI Interne

```bash
#!/bin/bash
# setup-internal-pki.sh

# Créer une CA interne
openssl genrsa -out ca-key.pem 4096

openssl req -new -x509 -days 3650 -key ca-key.pem -out ca.pem \
  -subj "/C=FR/ST=IDF/L=Paris/O=Company/OU=IT/CN=Internal CA"

# Créer un certificat pour Harbor
openssl genrsa -out harbor-key.pem 4096

openssl req -new -key harbor-key.pem -out harbor.csr \
  -subj "/C=FR/ST=IDF/L=Paris/O=Company/OU=IT/CN=harbor.internal.company.com"

# Signer avec la CA
openssl x509 -req -days 730 -in harbor.csr \
  -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
  -out harbor-cert.pem \
  -extfile <(printf "subjectAltName=DNS:harbor.internal.company.com,DNS:*.harbor.internal.company.com")

# Créer secret Kubernetes
kubectl create secret tls harbor-tls \
  --cert=harbor-cert.pem \
  --key=harbor-key.pem \
  -n harbor

# Distribuer la CA aux nodes
sudo cp ca.pem /usr/local/share/ca-certificates/company-internal-ca.crt
sudo update-ca-certificates
```

### Politique de Sécurité Stricte

```yaml
# security-policies.yaml

# 1. PodSecurityPolicy stricte
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-airgap
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  readOnlyRootFilesystem: true

---
# 2. NetworkPolicy par défaut deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# 3. Egress bloqué vers Internet
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-external-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Autoriser uniquement le réseau interne
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
  - to:
    - ipBlock:
        cidr: 192.168.0.0/16
  # DNS interne
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## 📚 Checklist Air-Gap

### Préparation
- [ ] Liste complète des images nécessaires
- [ ] Liste des binaires et versions
- [ ] Liste des Helm charts et dépendances
- [ ] Création du bundle avec checksums
- [ ] Tests du bundle en environnement isolé de test
- [ ] Documentation complète de l'installation
- [ ] Procédure de rollback documentée

### Infrastructure Air-Gap
- [ ] DNS interne configuré
- [ ] NTP interne configuré
- [ ] PKI interne déployée
- [ ] SMTP interne (pour alertes)
- [ ] Registre d'images opérationnel
- [ ] Repository Git interne
- [ ] Artifact repository pour binaires

### Sécurité
- [ ] Network policies deny-all par défaut
- [ ] Pas d'accès Internet depuis les pods
- [ ] Audit logging activé
- [ ] Certificats TLS pour tous les services
- [ ] RBAC strictement configuré
- [ ] Secrets management (Vault/Sealed Secrets)

### Opérations
- [ ] Procédure de mise à jour documentée
- [ ] Scripts d'import d'images
- [ ] Monitoring sans dépendance externe
- [ ] Logs centralisés
- [ ] Backup automatique configuré
- [ ] Plan de reprise d'activité (DRP)

## 🔗 Références

- [Kubernetes Air-Gap Installation Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Hauler by Rancher Federal](https://github.com/rancherfederal/hauler)
- [Carvel Tools](https://carvel.dev/)
- [Harbor Air-Gap Installation](https://goharbor.io/docs/latest/install-config/)
- [NIST Air-Gap Guidance](https://csrc.nist.gov/glossary/term/air_gap)

## Articles Complémentaires

- [Gestion de Cluster Sécurisé](SECURE_CLUSTER_MANAGEMENT.md)
- [Registres d'Images en DMZ](IMAGE_REGISTRY_DMZ.md)
- [Cycle de Vie des Applications](APPLICATION_LIFECYCLE.md)
