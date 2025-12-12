# Claude Hooks - Kubernetes Formation

Ce répertoire contient les hooks Claude pour automatiser les vérifications du projet.

## Session Start Hook

Le hook `session-start.sh` s'exécute automatiquement au début de chaque session Claude pour :

### 1. Vérifications des outils Kubernetes
- ✅ Détection des versions de kubectl, minikube, helm
- ⚠️ Alerte si versions obsolètes (< 1.28 pour kubectl)
- 📊 Vérification de la compatibilité version client/serveur

### 2. État du cluster
- ✅ Vérifie si un cluster Kubernetes est accessible
- 📊 Affiche la version du serveur et le nombre de nœuds
- ⚠️ Détecte les écarts de version (version skew)

### 3. Validation des manifests YAML
- ✅ Valide la syntaxe de tous les fichiers YAML
- 🔍 **Détecte les API Kubernetes obsolètes/dépréciées** :
  - `extensions/v1beta1` → SUPPRIMÉ (utiliser `apps/v1`)
  - `apps/v1beta1`, `apps/v1beta2` → SUPPRIMÉS (utiliser `apps/v1`)
  - `policy/v1beta1` → Déprécié (utiliser `policy/v1`)
  - `autoscaling/v2beta1`, `v2beta2` → Dépréciés (utiliser `autoscaling/v2`)

### 4. Vérification GitHub Actions
- ✅ Vérifie si les workflows sont déployés
- ⚠️ Détecte les versions obsolètes des actions :
  - `actions/checkout@v3` → v4 disponible
  - `actions/setup-python@v4` → v5 disponible
  - `azure/setup-kubectl@v3` → v4 disponible

### 5. Scripts de test disponibles
- 📋 Liste tous les scripts de test dans les TPs
- ✅ Indique lesquels sont exécutables
- 💡 Suggère les tests à exécuter si un cluster est disponible

### 6. Statistiques du projet
- 📊 Compte les fichiers YAML, Markdown, scripts
- 📊 Affiche le nombre de TPs
- 🔍 Vérifie l'état Git (branche, modifications)

## Utilisation

### Exécution automatique
Le hook s'exécute automatiquement au début de chaque session Claude si configuré dans les paramètres.

### Exécution manuelle
```bash
./.claude/hooks/session-start.sh
```

## Configuration

Pour activer le hook dans Claude Code, ajouter dans les paramètres :

```json
{
  "hooks": {
    "session-start": ".claude/hooks/session-start.sh"
  }
}
```

## Codes de sortie

- **0** : Tous les tests passent (warnings autorisés)
- **1** : Erreurs critiques détectées (tools manquants, erreurs YAML)

## Exemples de sortie

### ✅ Projet en bon état
```
╔════════════════════════════════════════════════════════════╗
║  Kubernetes Formation - Session Start Verification        ║
╚════════════════════════════════════════════════════════════╝

▶ 1. Kubernetes Tooling Versions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ kubectl is installed
  Version: v1.28.0
✓ minikube is installed
  Version: v1.32.0

▶ 7. Summary & Recommendations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ All checks passed!
```

### ⚠️ APIs dépréciées détectées
```
▶ 3. YAML Manifest Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Found 125 YAML manifest files

✗ tp4/monitoring.yaml has deprecated APIs:
  - policy/v1beta1 PodDisruptionBudget is deprecated (use policy/v1)

⚠ All YAML files are syntactically valid
⚠ Found 1 file(s) with deprecated APIs
```

## Règles de vérification

### API Kubernetes dépréciées
Le hook vérifie systématiquement les APIs obsolètes selon les changements Kubernetes jusqu'à la version 1.29+ :

| API obsolète | Statut | Remplacement |
|--------------|--------|--------------|
| `extensions/v1beta1` | ❌ SUPPRIMÉ | `apps/v1` |
| `apps/v1beta1` | ❌ SUPPRIMÉ | `apps/v1` |
| `apps/v1beta2` | ❌ SUPPRIMÉ | `apps/v1` |
| `policy/v1beta1` (PDB) | ⚠️ Déprécié | `policy/v1` |
| `autoscaling/v2beta1` | ⚠️ Déprécié | `autoscaling/v2` |
| `autoscaling/v2beta2` | ⚠️ Déprécié | `autoscaling/v2` |

### Versions d'outils recommandées
- **kubectl** : >= 1.28.0
- **Kubernetes** : >= 1.28.0
- **Version skew** : kubectl ±1 version mineure du serveur

## Actions recommandées après exécution

En fonction des résultats, le hook suggère :

1. **🔧 Installation d'outils manquants**
   ```bash
   # Installer kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

   # Installer minikube
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   ```

2. **⬆️ Mise à jour des APIs dépréciées**
   ```bash
   # Remplacer policy/v1beta1 par policy/v1
   find . -name "*.yaml" -exec sed -i 's/policy\/v1beta1/policy\/v1/g' {} +
   ```

3. **🧪 Exécution des tests**
   ```bash
   # Si cluster disponible
   ./tp5/test-tp5.sh
   ./tp8/test-tp8.sh
   ./tp9/test-tp9.sh
   ```

4. **📦 Déploiement des GitHub Actions**
   ```bash
   mkdir -p .github/workflows
   cp github-workflows-setup/test-kubernetes-manifests.yml .github/workflows/
   ```

## Maintenance du hook

Le hook doit être mis à jour régulièrement pour :
- ✅ Ajouter de nouvelles vérifications d'API dépréciées
- ✅ Mettre à jour les versions recommandées d'outils
- ✅ Ajouter de nouveaux tests automatisés
- ✅ Améliorer la détection des problèmes courants

## Intégration avec CI/CD

Ce hook complète les GitHub Actions en fournissant :
- ✅ Vérifications locales avant commit
- ✅ Détection précoce des problèmes
- ✅ Validation de l'environnement de développement
- ✅ Feedback immédiat sur l'état du projet
