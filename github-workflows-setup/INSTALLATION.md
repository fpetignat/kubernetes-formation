# Installation des Workflows GitHub Actions

Ce dossier contient les workflows GitHub Actions pour tester automatiquement les TPs de la formation Kubernetes.

## Pourquoi ce dossier ?

Les fichiers de workflow GitHub Actions (`.github/workflows/`) ne peuvent pas être créés directement par certaines apps GitHub sans permissions spéciales. Ce dossier contient les fichiers prêts à installer.

## Installation automatique (recommandé)

Exécutez le script d'installation depuis la racine du projet :

```bash
# Depuis la racine du projet kubernetes-formation
chmod +x github-workflows-setup/INSTALL.sh
./github-workflows-setup/INSTALL.sh
```

Le script va :
1. Créer le dossier `.github/workflows/`
2. Copier les fichiers de workflow
3. Afficher les prochaines étapes

## Installation manuelle

Si vous préférez installer manuellement :

```bash
# Depuis la racine du projet
mkdir -p .github/workflows

# Copier les fichiers
cp github-workflows-setup/test-kubernetes-manifests.yml .github/workflows/
cp github-workflows-setup/README.md .github/workflows/
```

## Après l'installation

1. **Vérifier les fichiers** :
   ```bash
   ls -la .github/workflows/
   ```

2. **Committer les changements** :
   ```bash
   git add .github/ README.md
   git commit -m "Add GitHub Actions tests for Kubernetes formation"
   ```

3. **Pousser vers GitHub** :
   ```bash
   git push origin $(git branch --show-current)
   ```

## Ce qui sera testé

Une fois installés, les workflows GitHub Actions testeront automatiquement :

### ✅ TP3 - Persistance des données
- **9 fichiers YAML** testés avec validation de syntaxe
- **Tests d'intégration** sur cluster Minikube réel
- Validation des PersistentVolumes, PVCs, et StorageClasses

### ✅ Tous les TPs - Manifests README
- **~163 manifests** extraits et validés depuis les README
- TP1: ~3 manifests
- TP2: ~35 manifests
- TP3: ~14 manifests
- TP4: ~23 manifests
- TP5: ~45 manifests
- TP6: ~43 manifests

### ✅ Qualité documentation
- Vérification de l'existence de tous les README
- Détection de code blocks non fermés
- Validation de la structure markdown

## Fichiers inclus

- `test-kubernetes-manifests.yml` : Workflow principal avec 5 jobs de tests
- `README.md` : Documentation détaillée des tests
- `INSTALL.sh` : Script d'installation automatique
- `INSTALLATION.md` : Ce fichier d'instructions

## Déclenchement des tests

Les tests s'exécutent automatiquement sur :
- Tous les push vers `main`
- Tous les push vers les branches `claude/**`
- Toutes les pull requests vers `main`

## Voir les résultats

Après avoir poussé les changements :
1. Aller sur https://github.com/aboigues/kubernetes-formation
2. Cliquer sur l'onglet "Actions"
3. Voir les résultats des workflows

Le badge de statut dans le README principal affichera l'état des tests.

## Support

Pour plus de détails sur les tests, consultez `.github/workflows/README.md` après l'installation.

## Nettoyage

Une fois les workflows installés et poussés sur GitHub, vous pouvez supprimer ce dossier :

```bash
rm -rf github-workflows-setup/
```
