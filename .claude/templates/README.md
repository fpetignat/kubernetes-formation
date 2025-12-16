# Templates Kubernetes Sécurisés

Ce répertoire contient des templates de manifests Kubernetes pré-configurés avec toutes les bonnes pratiques de sécurité.

## 📋 Templates disponibles

### 1. `secure-deployment.yaml`
Template de Deployment sécurisé avec :
- ✅ SecurityContext complet (pod + container)
- ✅ readOnlyRootFilesystem activé
- ✅ Resources limits définis
- ✅ Health checks configurés
- ✅ Volumes emptyDir pour répertoires temporaires

## 🚀 Utilisation

```bash
# Copier le template
cp .claude/templates/secure-deployment.yaml tp<N>/mon-deployment.yaml

# Adapter selon vos besoins :
# 1. Changer le nom de l'application
# 2. Changer l'image Docker
# 3. Adapter runAsUser selon l'image (voir guide)
# 4. Ajouter volumes nécessaires selon l'application
# 5. Adapter les resources selon les besoins

# Valider avant commit
trivy config --severity HIGH,CRITICAL tp<N>/mon-deployment.yaml
kubeconform -strict tp<N>/mon-deployment.yaml
kubectl apply --dry-run=server -f tp<N>/mon-deployment.yaml
```

## 🎯 UIDs recommandés par image

| Image Docker | UID | GID | Notes |
|--------------|-----|-----|-------|
| `nginx:alpine` | 101 | 101 | Utilisateur nginx |
| `postgres:alpine` | 70 | 70 | Utilisateur postgres |
| `redis:alpine` | 999 | 999 | Utilisateur redis |
| `grafana/grafana` | 472 | 472 | Utilisateur grafana |
| `prom/prometheus` | 65534 | 65534 | Utilisateur nobody |
| `python:slim` | 1000 | 1000 | Créer utilisateur non-root |

## 📚 Documentation complète

Voir `.claude/SECURITY.md` pour :
- Checklist exhaustive de sécurité
- Explications détaillées de chaque pratique
- Cas spéciaux et exemples
- Guide de validation

## ⚠️ Rappel

**30 vulnérabilités HIGH** ont été corrigées a posteriori dans le TP10.
En utilisant ces templates dès le départ, nous évitons ce type de problème.

---

**Dernière mise à jour** : 2025-12-16
