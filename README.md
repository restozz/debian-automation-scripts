# 🔧 debian-automation-scripts

Scripts d'automatisation système pour Debian - Compatible avec Script Launcher Hub

## 📦 Scripts disponibles

- **setup_debian_vm.sh** - Configuration post-installation Debian 13 (SSH, UFW, Fail2Ban)
- **install_docker.sh** - Installation complète de Docker et Docker Compose
- **install_proxmox_agent.sh** - Installation QEMU Guest Agent pour Proxmox VE

## 🚀 Utilisation

### Avec le launcher (recommandé)
```bash
sudo ./launcher.sh
# → G: Configurer dépôt GitHub
# → URL: https://github.com/votre-user/debian-automation-scripts.git
# → R: Rafraîchir la liste des scripts
# → Sélectionnez un script pour l'exécuter (téléchargement automatique)
```

### Exécution directe
```bash
git clone https://github.com/votre-user/debian-automation-scripts.git
cd debian-automation-scripts
chmod +x *.sh
sudo ./setup_debian_vm.sh
```

## 📝 Format des scripts

Chaque script doit contenir :
```bash
#!/bin/bash
# Description: Courte description (max 70 caractères)

# Votre code...
```

## 📂 Structure

```
debian-automation-scripts/
├── README.md
├── launcher.sh                 # Launcher avec téléchargement à la demande
├── setup_debian_vm.sh          # Post-install Debian
└── install_docker.sh           # Docker
```

## ✨ Fonctionnement du launcher

Le launcher télécharge automatiquement les scripts depuis GitHub **uniquement au moment de l'exécution** :
- ✅ Pas besoin de cloner tout le dépôt
- ✅ Scripts toujours à jour
- ✅ Économie d'espace disque
- ✅ **Support des dépôts privés** avec authentification automatique
- ✅ **Détection automatique de l'OS** (Debian, Ubuntu) avec variables exportées

### 🖥️ Détection automatique du système

Le launcher détecte automatiquement votre système d'exploitation et expose ces informations à tous les scripts :

- **OS_ID** : debian, ubuntu, etc.
- **OS_VERSION** : 13, 12, 24.04, etc.
- **OS_CODENAME** : trixie, bookworm, noble, etc.

Les scripts s'adaptent automatiquement à votre distribution !

### 🔒 Dépôts privés

Le launcher détecte automatiquement si votre dépôt est privé et vous demande un Personal Access Token :

1. Créer un token sur GitHub :
   - Settings → Developer settings → Personal access tokens
   - Generate new token (classic)
   - Permissions : **repo** (full control)
2. Entrer le token dans le launcher
3. Le token est stocké en sécurité (permissions 600)

### 📝 Créer vos propres scripts

Consultez **BONNES_PRATIQUES.md** pour :
- Utiliser les variables OS dans vos scripts
- Standards de code
- Checklist avant commit

## 👤 Auteur

Eloïd DOPPEL - Administrateur Système et Réseaux

## 📄 Licence

MIT License
