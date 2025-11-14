# 📦 Fichiers prêts pour déploiement

## Fichiers à télécharger

### Pour votre serveur
- `launcher.sh` - Launcher principal

### Pour votre dépôt GitHub: `debian-automation-scripts`
Dossier `github-repo/` contient:
- `README.md` - Documentation du dépôt
- `SETUP_GUIDE.md` - Guide de mise en place
- `setup_debian_vm.sh` - Config Debian 13
- `install_docker.sh` - Installation Docker

## Actions rapides

### 1. Créer le dépôt GitHub
Nom: **debian-automation-scripts**
https://github.com/new

### 2. Uploader les scripts
```bash
cd github-repo/
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/VOTRE-USER/debian-automation-scripts.git
git push -u origin main
```

### 3. Installer sur serveur
```bash
wget https://raw.githubusercontent.com/VOTRE-USER/debian-automation-scripts/main/launcher.sh
chmod +x launcher.sh
sudo ./launcher.sh
```

### 4. Configurer
Dans le menu:
- G → Entrez URL du dépôt
- Les scripts s'affichent automatiquement

## Résultat final

Menu du launcher:
```
1. Configuration post-installation Debian 13 (Local)
2. Installation complète de Docker et Docker Compose (Local)
[...autres scripts depuis GitHub...]

G. Configurer dépôt GitHub
R. Rafraîchir la liste des scripts
Q. Quitter
```

**Note**: Les scripts sont téléchargés automatiquement depuis GitHub lors de la sélection.

Tout est prêt à l'emploi ! 🚀
