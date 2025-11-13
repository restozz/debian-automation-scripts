# 🚀 Guide de mise en place du dépôt GitHub

## Nom de dépôt proposé
`debian-automation-scripts`

## Étapes de création

### 1. Créer le dépôt sur GitHub
```
Nom: debian-automation-scripts
Description: Scripts d'automatisation système pour infrastructure Debian
Public ou Privé: Au choix
```

### 2. Initialiser localement
```bash
cd /tmp
mkdir debian-automation-scripts
cd debian-automation-scripts

# Copier les fichiers du dossier github-repo
cp /chemin/vers/README.md .
cp /chemin/vers/setup_debian_vm.sh .
cp /chemin/vers/install_docker.sh .
cp /chemin/vers/setup_monitoring.sh .

# Initialiser git
git init
git add .
git commit -m "Initial commit: Scripts d'automatisation Debian"
git branch -M main
git remote add origin https://github.com/VOTRE-USER/debian-automation-scripts.git
git push -u origin main
```

### 3. Utiliser avec le launcher

#### Installation
```bash
# Copier le launcher sur votre serveur
scp launcher.sh root@votre-serveur:/root/
scp setup_debian_vm.sh root@votre-serveur:/root/

# Sur le serveur
chmod +x /root/launcher.sh
chmod +x /root/setup_debian_vm.sh
```

#### Configuration
```bash
sudo /root/launcher.sh
# → Appuyez sur G
# → Entrez: https://github.com/VOTRE-USER/debian-automation-scripts.git
```

Le launcher clone automatiquement le dépôt et affiche tous vos scripts.

### 4. Ajouter de nouveaux scripts

#### Sur GitHub
1. Créer votre script avec `# Description:` en ligne 2
2. Commit & push
3. Sur le serveur: launcher → U (Update)

#### Structure d'un script
```bash
#!/bin/bash
# Description: Votre description (max 70 caractères)

# Votre code...
```

## 📁 Structure finale du serveur

```
/root/
├── launcher.sh                    # Launcher principal
├── setup_debian_vm.sh            # Script Debian (local, toujours dispo)
├── .launcher_config              # Config (créé auto)
└── scripts/                       # Clone du dépôt GitHub (créé auto)
    ├── .git/
    ├── README.md
    ├── setup_debian_vm.sh
    ├── install_docker.sh
    └── setup_monitoring.sh
```

## 🔄 Workflow

1. Développer scripts localement
2. Push sur GitHub
3. Sur serveur: `launcher.sh` → U → Scripts à jour

## 💡 Conseils

- Le script `setup_debian_vm.sh` local reste en position 1
- Les scripts GitHub sont numérotés à partir de 2
- Utilisez `# Description:` pour une bonne présentation dans le menu
- Pensez à `chmod +x` vos scripts avant de commit
