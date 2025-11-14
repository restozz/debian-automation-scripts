# 🔧 debian-automation-scripts

Scripts d'automatisation système pour Debian - Compatible avec Script Launcher Hub

## 📦 Scripts disponibles

- **setup_debian_vm.sh** - Configuration post-installation Debian 13 (SSH, UFW, Fail2Ban)
- **install_docker.sh** - Installation complète de Docker et Docker Compose

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

## 👤 Auteur

Felix - Administrateur Système et Réseaux
- Infrastructure multi-site (UniFi SD-WAN)
- Formateur BTS CIEL
- DoppelServices

## 📄 Licence

MIT License
