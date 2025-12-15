# Configuration Claude - Kubernetes Formation

## À lire au début de CHAQUE session

**IMPORTANT** : Avant de commencer toute tâche, lire obligatoirement ces fichiers dans cet ordre :

1. **`.claude/CONTEXT.md`** - Historique complet du projet et décisions importantes
2. **`.claude/INSTRUCTIONS.md`** - Workflow Git et règles de travail
3. **`.claude/AUTOMATION.md`** - Détails sur l'automatisation et CI/CD

## Description du projet

**Nom** : kubernetes-formation
**Type** : Formation Kubernetes (9 TPs)
**Utilisateur** : aboigues
**Repository** : https://github.com/aboigues/kubernetes-formation.git

Formation complète sur Kubernetes avec :
- 9 TPs progressifs (tp1 à tp9)
- 124 manifests YAML validés
- CI/CD complet avec GitHub Actions
- Tests d'intégration automatisés
- Préparation à la certification CKAD

## État actuel du projet

**Dernière mise à jour** : 2025-12-12

**Statistiques** :
- ✅ 124 manifests YAML validés
- ✅ 0 APIs dépréciées détectées
- ✅ 56 fichiers Markdown
- ✅ 9 TPs complets
- ✅ 4 scripts de test automatisés (TP3, TP5, TP8, TP9)
- ✅ 10 jobs GitHub Actions

**Stack technique** :
- Kubernetes 1.29.0
- Python 3.12
- kubeconform 0.6.6
- Trivy pour scan de sécurité

## Automatisation en place

### Session-Start Hook
Le hook `.claude/hooks/session-start.sh` s'exécute automatiquement et vérifie :
1. ✅ Versions des outils Kubernetes (kubectl, minikube, helm)
2. ✅ État du cluster Kubernetes
3. ✅ Validation syntaxe de tous les YAML
4. ✅ Détection des APIs dépréciées/supprimées
5. ✅ Vérification des versions GitHub Actions
6. ✅ Liste des scripts de test disponibles
7. ✅ Statistiques du projet

### GitHub Actions CI/CD
Workflow `.github/workflows/test-kubernetes-manifests.yml` avec 10 jobs :
- Validation YAML (syntaxe + schémas Kubernetes)
- Détection d'APIs obsolètes
- Tests d'intégration (TP3, TP5, TP8, TP9)
- Scan de sécurité avec Trivy
- Validation des README

## Règles de travail importantes

### Workflow Git
- **Branche de développement** : `claude/integrate-claude-config-nzHvu`
- **Toujours** développer sur la branche désignée
- **Jamais** pousser directement sur `main` sans PR
- **Format de commit** : Voir `.claude/INSTRUCTIONS.md`

### Avant chaque commit
- [ ] Tous les YAML syntaxiquement valides
- [ ] Aucune API dépréciée ou supprimée
- [ ] Tests passent (si applicable)
- [ ] Documentation à jour
- [ ] CONTEXT.md mis à jour si changements majeurs

### Avant chaque push
- [ ] git push -u origin <branch-name>
- [ ] Retry jusqu'à 4 fois si erreur réseau (backoff exponentiel)
- [ ] Vérifier que la branche commence par 'claude/' et se termine par le session ID

## Structure du projet

```
kubernetes-formation/
├── .claude/                     # Configuration et contexte Claude
│   ├── CONTEXT.md              # Historique et décisions (LIRE EN PRIORITÉ)
│   ├── INSTRUCTIONS.md         # Workflow et règles de travail
│   ├── AUTOMATION.md           # Documentation automatisation
│   ├── QUICKSTART.md           # Guide de démarrage rapide
│   └── hooks/
│       ├── session-start.sh    # Hook de validation automatique
│       └── README.md           # Documentation des hooks
├── .github/workflows/          # CI/CD GitHub Actions
├── tp1/ à tp9/                 # 9 TPs de formation
├── docs/                       # Documentation supplémentaire
├── settings.json               # Configuration Claude Code
└── CLAUDE.md                   # Ce fichier (contexte session)
```

## APIs Kubernetes surveillées

**APIs supprimées** (erreur si trouvées) :
- `extensions/v1beta1` → utiliser `apps/v1`
- `apps/v1beta1`, `apps/v1beta2` → utiliser `apps/v1`

**APIs dépréciées** (warning) :
- `policy/v1beta1` → utiliser `policy/v1`
- `autoscaling/v2beta1`, `v2beta2` → utiliser `autoscaling/v2`
- `batch/v1beta1` (CronJob) → utiliser `batch/v1`
- `networking.k8s.io/v1beta1` → utiliser `networking.k8s.io/v1`

## Commandes utiles

```bash
# Exécuter le hook manuellement
./.claude/hooks/session-start.sh

# Voir l'état Git
git status
git log --oneline -10

# Exécuter les tests (si cluster disponible)
./tp5/test-tp5.sh    # RBAC et sécurité
./tp8/test-tp8.sh    # Réseau
./tp9/test-tp9.sh    # Multi-nœuds
```

## Ressources de référence

- [Kubernetes API Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)
- [Documentation du projet](.claude/AUTOMATION.md)
- [Workflow de travail](.claude/INSTRUCTIONS.md)
- [Historique complet](.claude/CONTEXT.md)

## Prochaines étapes suggérées

Voir `.claude/CONTEXT.md` section "Prochaines étapes" pour :
- Court terme : Tests TP4, TP6, badge CI/CD
- Moyen terme : Pre-commit hooks, validation Dockerfiles
- Long terme : Dashboard qualité, tests de performance

---

**RAPPEL** : Toujours lire `.claude/CONTEXT.md` et `.claude/INSTRUCTIONS.md` avant de commencer une nouvelle tâche !
