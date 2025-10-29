# QUICKSTART - Claude - kubernetes-lab

## Début de session

```bash
# 1. Retrouver contexte
conversation_search: "kubernetes-lab"

# 2. Cloner
cd /home/claude
git clone https://TOKEN@github.com/aboigues/kubernetes-formation.git
cd kubernetes-formation

# 3. Lire instructions
cat .claude/INSTRUCTIONS.md

# 4. Lire contexte
cat .claude/CONTEXT.md
```

## Workflow standard

```bash
# Modifier selon demande
# ...

# Mettre à jour contexte
echo "## Session $(date +%Y-%m-%d)" >> .claude/CONTEXT.md
echo "- [Changements]" >> .claude/CONTEXT.md

# Push
git add .
git commit -m "Session $(date +%Y-%m-%d): Description"
git push origin main

# Outputs
cp -r . /mnt/user-data/outputs/kubernetes-lab/
```

## Règles essentielles

- Toujours partir de la dernière version Git
- Mettre à jour CONTEXT.md
- Messages de commit clairs
- Documenter les changements importants

## Repository

https://github.com/aboigues/kubernetes-formation.git
