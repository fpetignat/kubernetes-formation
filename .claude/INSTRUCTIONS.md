# INSTRUCTIONS POUR CLAUDE - kubernetes-lab

## Contexte du projet

**Projet:** kubernetes-lab
**Type:** formation
**Description:** formation sur Kubernetes
**Utilisateur:** aboigues
**Repository:** https://github.com/aboigues/kubernetes-formation.git

## Objectif

[Décrire l'objectif principal du projet]

## Règles importantes

1. **Historisation obligatoire**: Tous les livrables doivent être versionnés sur GitHub
2. **Itération**: Chaque session doit partir de la dernière version sur GitHub
3. **Documentation**: Maintenir la documentation à jour
4. **Tests**: [Ajouter les règles de tests si applicable]
5. **🔐 SÉCURITÉ KUBERNETES**: Appliquer SYSTÉMATIQUEMENT la checklist `.claude/SECURITY.md` dès la première itération

## Workflow à suivre à chaque session

### 1. Retrouver le contexte

```bash
# Rechercher les conversations précédentes
conversation_search: "kubernetes-lab"

# Ou voir les sessions récentes
recent_chats: n=5
```

### 2. Cloner le repository

```bash
cd /home/claude
git clone https://TOKEN@github.com/aboigues/kubernetes-formation.git
cd kubernetes-formation
```

### 3. Analyser l'état actuel

```bash
# Voir l'historique
git log --oneline -10

# Voir la structure
ls -la

# Lire les derniers changements
git log -1 --stat

# Lire le contexte
cat .claude/CONTEXT.md
```

### 4. Effectuer les modifications

[Décrire les étapes spécifiques au projet]

### 5. Mettre à jour le contexte

```bash
# Mettre à jour CONTEXT.md avec les changements importants
echo "## Session $(date +%Y-%m-%d)" >> .claude/CONTEXT.md
echo "- [Description des changements]" >> .claude/CONTEXT.md
```

### 6. Committer et pousser

```bash
git add .
git commit -m "Session $(date +%Y-%m-%d): [Description]"
git push origin main
```

### 7. Mettre à disposition

```bash
# Copier dans outputs pour téléchargement
cp -r . /mnt/user-data/outputs/kubernetes-lab/
```

## Structure du projet

```
kubernetes-lab/
├── README.md                  # Documentation principale
├── .claude/                   # Configuration Claude
│   ├── INSTRUCTIONS.md        # Ce fichier
│   ├── QUICKSTART.md          # Démarrage rapide
│   └── CONTEXT.md             # Historique et contexte
├── docs/                      # Documentation
├── src/                       # Code source
├── data/                      # Données
└── tests/                     # Tests
```

## Technologies utilisées

[Lister les technologies, frameworks, outils]

## Commandes essentielles

### Git

```bash
# Cloner
git clone https://TOKEN@github.com/aboigues/kubernetes-formation.git

# Statut
git status

# Historique
git log --oneline -20
git log --graph --oneline --all

# Différences
git diff

# Pousser
git add .
git commit -m "Message"
git push origin main
```

### Projet spécifiques

[Ajouter les commandes spécifiques au projet]

## Checklist avant chaque push

- [ ] Le code fonctionne
- [ ] Les tests passent (si applicable)
- [ ] La documentation est à jour
- [ ] CONTEXT.md est mis à jour
- [ ] Le message de commit est clair
- [ ] Aucun secret/token dans le code
- [ ] 🔐 **Checklist sécurité Kubernetes appliquée** (voir `.claude/SECURITY.md`)

## 🔐 Checklist Sécurité Kubernetes (OBLIGATOIRE pour manifests)

**Avant de créer/modifier un manifest Kubernetes, TOUJOURS suivre :**

### Étape 1 : Partir du template sécurisé
Voir `.claude/SECURITY.md` section "TEMPLATE DE DEPLOYMENT SÉCURISÉ"

### Étape 2 : SecurityContext - OBLIGATOIRE ✅
```yaml
# POD Level
securityContext:
  runAsNonRoot: true
  runAsUser: 1000  # UID non-root
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

# CONTAINER Level
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL
```

### Étape 3 : Volumes (si readOnlyRootFilesystem: true) ✅
```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

### Étape 4 : Resources - OBLIGATOIRE ✅
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Étape 5 : Validation AVANT commit ✅
```bash
# Scan de sécurité (0 vulnérabilité HIGH/CRITICAL attendu)
trivy config --severity HIGH,CRITICAL <file>

# Validation syntaxe
kubeconform -strict <file>

# Dry-run
kubectl apply --dry-run=server -f <file>
```

**📖 Guide complet** : `.claude/SECURITY.md`
**🎯 UIDs recommandés** : nginx=101, postgres=70, redis=999, grafana=472, prometheus=65534

---

## ⚠️ Rappel Important

**30 vulnérabilités HIGH** ont été corrigées a posteriori dans le TP10.
**Objectif** : 0 vulnérabilité dès la première itération en appliquant la checklist ci-dessus.

## Messages de commit standards

```
# Ajout de fonctionnalité
"feat: [description]"
"add: [élément ajouté]"

# Modifications
"update: [élément modifié]"
"improve: [amélioration]"

# Corrections
"fix: [problème corrigé]"
"bugfix: [bug corrigé]"

# Documentation
"docs: [modification documentation]"

# Refactoring
"refactor: [restructuration]"

# Sessions
"session YYYY-MM-DD: [résumé]"
```

## Comment retrouver ce document

```bash
# Méthode 1: Rechercher dans conversations
conversation_search: "instructions kubernetes-lab"

# Méthode 2: Cloner et lire
git clone https://TOKEN@github.com/aboigues/kubernetes-formation.git
cat kubernetes-formation/.claude/INSTRUCTIONS.md

# Méthode 3: Chercher sur Drive (si synchronisé)
google_drive_search: "INSTRUCTIONS kubernetes-lab"
```

## Scénarios d'utilisation

### Scénario 1: Ajouter une fonctionnalité

1. Cloner le repo
2. Créer la fonctionnalité
3. Tester
4. Documenter
5. Mettre à jour CONTEXT.md
6. Committer: "feat: [description]"
7. Pousser

### Scénario 2: Corriger un bug

1. Cloner le repo
2. Identifier le problème
3. Corriger
4. Tester
5. Committer: "fix: [description]"
6. Pousser

### Scénario 3: Refactoring

1. Cloner le repo
2. Restructurer le code
3. S'assurer que tout fonctionne
4. Mettre à jour la documentation
5. Committer: "refactor: [description]"
6. Pousser

## Contact et support

**Utilisateur:** aboigues
**Projet:** kubernetes-lab

---

**Document créé:** $(date +%Y-%m-%d)
**Version:** 1.0
