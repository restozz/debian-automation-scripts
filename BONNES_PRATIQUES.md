# 📋 Bonnes pratiques pour les scripts d'automatisation

Ce document définit les standards et bonnes pratiques pour tous les scripts de ce dépôt.

---

## 🎯 Structure de base d'un script

### Header obligatoire

```bash
#!/bin/bash
# Description: Description courte (max 70 caractères pour le menu)

################################################################################
# Nom du script / Objectif
# Auteur: Eloïd DOPPEL
# Description: Description détaillée du script
################################################################################

set -e  # Arrêt en cas d'erreur
```

---

## 🌍 Variables d'environnement fournies par le launcher

Le launcher détecte automatiquement le système et expose les variables suivantes :

### Variables OS (toujours disponibles)

```bash
$OS_ID           # Identifiant de la distribution (ex: "debian", "ubuntu")
$OS_VERSION      # Version de la distribution (ex: "13", "24.04")
$OS_CODENAME     # Nom de code de la version (ex: "trixie", "noble")
$OS_PRETTY_NAME  # Nom complet (ex: "Debian GNU/Linux 13 (trixie)")
```

### Variables système

```bash
$LAUNCHER_DIR    # Répertoire du launcher (où se trouvent les scripts locaux)
```

### Exemple d'utilisation

```bash
#!/bin/bash
# Description: Installation d'un paquet selon la distribution

# Récupérer les variables OS du launcher (si disponibles)
if [ -z "$OS_ID" ]; then
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_ID="$ID"
        OS_VERSION="${VERSION_ID:-unknown}"
        OS_CODENAME="${VERSION_CODENAME:-unknown}"
        OS_PRETTY_NAME="${PRETTY_NAME:-unknown}"
    else
        echo "Erreur: Impossible de détecter le système"
        exit 1
    fi
fi

# Utiliser les variables
echo "Installation sur $OS_PRETTY_NAME"

if [ "$OS_ID" = "debian" ]; then
    apt-get install -y paquet-debian
elif [ "$OS_ID" = "ubuntu" ]; then
    apt-get install -y paquet-ubuntu
else
    echo "Distribution non supportée: $OS_ID"
    exit 1
fi
```

---

## 🎨 Couleurs et affichage

### Palette de couleurs standard

```bash
# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'  # No Color
```

### Fonctions d'affichage

```bash
# Fonctions standards
print_message() { echo -e "${BLUE}[→]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
```

### Exemples

```bash
print_message "Installation en cours..."
print_success "Installation réussie"
print_error "Échec de l'installation"
print_warning "Attention: version obsolète détectée"
```

---

## 🛡️ Gestion des erreurs

### Méthode simple (recommandée pour scripts courts)

```bash
set -e  # Arrêt automatique en cas d'erreur
```

### Méthode avancée (pour scripts complexes)

```bash
set -e

# Fonction de gestion d'erreur
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "Erreur à la ligne $line_number (code: $exit_code)"
    # Nettoyage si nécessaire
    exit $exit_code
}

# Fonction de nettoyage
cleanup() {
    # Nettoyer les fichiers temporaires
    rm -f /tmp/script_temp_*
}

# Configuration des traps
trap 'handle_error ${LINENO}' ERR
trap cleanup EXIT
```

### Messages d'erreur explicites

**IMPORTANT**: Tous les scripts doivent envoyer des messages d'erreur clairs et informatifs.

#### Principes pour les messages d'erreur

1. **Toujours afficher un message d'erreur** avant de quitter
2. **Être explicite** : expliquer ce qui a échoué
3. **Être utile** : donner des pistes de résolution
4. **Utiliser print_error()** pour la cohérence visuelle

#### Exemples de bons messages d'erreur

```bash
# ❌ MAUVAIS - Message vague
if ! systemctl start docker; then
    print_error "Erreur"
    exit 1
fi

# ✅ BON - Message explicite avec contexte
if ! systemctl start docker; then
    print_error "Échec du démarrage du service Docker"
    print_message "Vérifiez les logs: journalctl -xe -u docker"
    exit 1
fi

# ✅ TRÈS BON - Message avec diagnostic
if ! systemctl start docker; then
    print_error "Échec du démarrage du service Docker"
    print_message "Vérification du statut..."
    systemctl status docker --no-pager || true
    print_message "Logs récents:"
    journalctl -xe -u docker -n 20 --no-pager
    exit 1
fi
```

#### Messages d'erreur avec action corrective

```bash
# Vérifier une commande avec solution
if ! command -v git &> /dev/null; then
    print_error "Git n'est pas installé"
    print_message "Pour installer: apt-get install git"
    exit 1
fi

# Vérifier un fichier avec explication
if [ ! -f "/etc/ssh/sshd_config" ]; then
    print_error "Fichier de configuration SSH introuvable"
    print_message "OpenSSH Server semble ne pas être installé"
    print_message "Installation: apt-get install openssh-server"
    exit 1
fi

# Vérifier une permission avec solution
if [ ! -w "/etc/hosts" ]; then
    print_error "Impossible d'écrire dans /etc/hosts"
    print_message "Ce script nécessite les privilèges root"
    print_message "Relancez avec: sudo $0"
    exit 1
fi
```

#### Messages d'erreur pour échecs réseau

```bash
# Test de connectivité avec message explicite
if ! curl -s -f "https://api.github.com" > /dev/null 2>&1; then
    print_error "Impossible de contacter api.github.com"
    print_warning "Vérifiez votre connexion Internet"
    print_message "Test: ping -c 3 8.8.8.8"
    exit 1
fi

# Téléchargement avec gestion d'erreur
if ! curl -sSL "https://example.com/file.tar.gz" -o /tmp/file.tar.gz; then
    print_error "Échec du téléchargement de file.tar.gz"
    print_message "URL: https://example.com/file.tar.gz"
    print_message "Vérifiez que l'URL est accessible"
    rm -f /tmp/file.tar.gz  # Nettoyer le fichier partiel
    exit 1
fi
```

#### Messages d'erreur pour validation de saisie utilisateur

```bash
# Validation d'une adresse IP
if ! [[ "$ip_address" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Format d'adresse IP invalide: $ip_address"
    print_message "Format attendu: xxx.xxx.xxx.xxx (ex: 192.168.1.10)"
    exit 1
fi

# Validation d'un port
if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    print_error "Numéro de port invalide: $port"
    print_message "Le port doit être entre 1 et 65535"
    exit 1
fi

# Validation d'un chemin
if [ ! -d "$directory" ]; then
    print_error "Le répertoire n'existe pas: $directory"
    print_message "Créez-le avec: mkdir -p $directory"
    exit 1
fi
```

#### Messages d'erreur avec code de sortie spécifique

```bash
# Utiliser des codes de sortie différents pour différents types d'erreur
# 1: Erreur générale
# 2: Mauvaise utilisation (arguments invalides)
# 3: Permissions insuffisantes
# 4: Dépendance manquante
# 5: Erreur réseau

# Exemple:
if [[ $EUID -ne 0 ]]; then
    print_error "Privilèges root requis"
    exit 3  # Code 3 = permissions
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker n'est pas installé"
    exit 4  # Code 4 = dépendance manquante
fi

if ! curl -s -f "https://download.docker.com" > /dev/null 2>&1; then
    print_error "Impossible de contacter download.docker.com"
    exit 5  # Code 5 = erreur réseau
fi
```

#### Template de fonction d'erreur avancée

```bash
# Fonction d'erreur avec logging et nettoyage
error_exit() {
    local message=$1
    local exit_code=${2:-1}
    local log_file=${3:-""}

    print_error "$message"

    # Logger dans un fichier si spécifié
    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR: $message" >> "$log_file"
    fi

    # Afficher les logs de debug si disponibles
    if [ -f "/tmp/script_debug.log" ]; then
        print_message "Logs de debug disponibles: /tmp/script_debug.log"
    fi

    # Nettoyage
    cleanup_on_error

    exit "$exit_code"
}

# Utilisation:
if ! systemctl start nginx; then
    error_exit "Échec du démarrage de Nginx" 1 "/var/log/setup.log"
fi
```

---

## ✅ Vérifications préalables

### Vérification des privilèges root

```bash
# Toujours vérifier si root est nécessaire
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root (sudo)"
   exit 1
fi
```

### Vérification de la compatibilité OS

```bash
# Vérifier la distribution supportée
if [[ "$OS_ID" != "debian" ]] && [[ "$OS_ID" != "ubuntu" ]]; then
    print_error "Ce script supporte uniquement Debian et Ubuntu"
    print_error "OS détecté: $OS_ID"
    exit 1
fi

# Vérifier une version minimale
if [[ "$OS_ID" = "debian" ]] && [[ "$OS_VERSION" -lt 12 ]]; then
    print_error "Debian 12 minimum requis (version détectée: $OS_VERSION)"
    exit 1
fi
```

### Vérification des dépendances

```bash
# Vérifier la présence d'une commande
if ! command -v curl &> /dev/null; then
    print_error "curl n'est pas installé"
    print_message "Installation: apt-get install curl"
    exit 1
fi
```

---

## 📦 Installation de paquets

### Installation selon la distribution

```bash
# Utiliser les variables OS pour adapter les commandes
if [ "$OS_ID" = "debian" ]; then
    # Configuration spécifique Debian
    apt-get update -qq
    apt-get install -y paquet-debian
elif [ "$OS_ID" = "ubuntu" ]; then
    # Configuration spécifique Ubuntu
    apt-get update -qq
    apt-get install -y paquet-ubuntu
fi
```

### Utiliser le codename pour les dépôts

```bash
# Ajouter un dépôt externe avec le bon codename
echo "deb https://example.com/repo $OS_CODENAME main" | \
    tee /etc/apt/sources.list.d/example.list > /dev/null
```

---

## 🔐 Sécurité

### Fichiers sensibles

```bash
# Toujours définir les bonnes permissions
chmod 600 /etc/app/config.conf      # Lecture/écriture propriétaire uniquement
chmod 700 /home/user/.ssh            # Répertoire SSH
chmod 644 /etc/app/public.conf      # Lecture pour tous, écriture propriétaire
```

### Backup avant modification

```bash
# Toujours créer une sauvegarde avant de modifier
BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/ssh/sshd_config "$BACKUP_FILE"

# Modifier le fichier
# ...

# Vérifier avant d'appliquer
if sshd -t; then
    systemctl restart sshd
else
    print_error "Configuration invalide, restauration..."
    cp "$BACKUP_FILE" /etc/ssh/sshd_config
    exit 1
fi
```

---

## 📊 Interface utilisateur

### Header de script (box)

```bash
clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  Titre du script                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_message "Système: $OS_PRETTY_NAME"
echo ""
```

### Barre de progression

```bash
echo -n "  [          ] 0% Initialisation..."
# Opération...
echo -e "\r  [▓▓        ] 20% Téléchargement..."
# Opération...
echo -e "\r  [▓▓▓▓▓     ] 50% Installation..."
# Opération...
echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Terminé ✓"
```

### Demande de confirmation

```bash
read -p "Voulez-vous continuer? (o/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    print_warning "Opération annulée"
    exit 0
fi
```

---

## 📝 Logging

### Log temporaire + permanent

```bash
# Log temporaire pendant l'exécution
TEMP_LOG="/tmp/script_debug_$(date +%Y%m%d_%H%M%S).log"
LOG_FILE="/var/log/script_$(date +%Y%m%d_%H%M%S).log"

# Logger toutes les commandes
exec > >(tee -a "$TEMP_LOG")
exec 2>&1

# En cas d'erreur, copier vers log permanent
handle_error() {
    cp "$TEMP_LOG" "$LOG_FILE"
    print_error "Log sauvegardé: $LOG_FILE"
}
```

---

## 🧪 Tests et validation

### Tester la syntaxe

```bash
# Avant de committer
bash -n script.sh
```

### Tester dans un environnement isolé

```bash
# Utiliser une VM Debian/Ubuntu propre
# Prendre un snapshot avant de tester
# Tester avec les différentes versions (Debian 12, 13, Ubuntu 22.04, 24.04)
```

---

## 📚 Documentation

### Commenter le code

```bash
# Commenter les sections importantes
# Expliquer le "pourquoi", pas le "quoi"

# Bon exemple:
# Désactiver le port 22 par défaut pour éviter les attaques automatisées
ufw deny 22/tcp

# Mauvais exemple:
# Bloquer le port 22
ufw deny 22/tcp
```

### Documentation des fonctions

```bash
# Fonction: installer_paquet
# Description: Installe un paquet selon la distribution détectée
# Arguments:
#   $1 - Nom du paquet à installer
# Retour: 0 si succès, 1 si échec
installer_paquet() {
    local paquet=$1
    print_message "Installation de $paquet"

    if apt-get install -y "$paquet" > /dev/null 2>&1; then
        print_success "$paquet installé"
        return 0
    else
        print_error "Échec installation de $paquet"
        return 1
    fi
}
```

---

## 🚀 Performance

### Optimisations

```bash
# Rediriger les sorties inutiles
apt-get update -qq                    # Mode quiet
apt-get install -y paquet > /dev/null 2>&1  # Pas de sortie

# Utiliser des pipes plutôt que des fichiers temporaires
curl -s https://url | grep pattern | awk '{print $1}'

# Minimiser les appels système
# Mauvais: boucle avec commande externe
for i in $(seq 1 100); do
    command $i
done

# Bon: tableau bash
for i in {1..100}; do
    command $i
done
```

---

## 📋 Checklist avant commit

- [ ] Shebang `#!/bin/bash` présent
- [ ] Description sur la ligne 2
- [ ] Header avec auteur et description détaillée
- [ ] `set -e` pour arrêt sur erreur
- [ ] Utilisation des variables `$OS_ID`, `$OS_VERSION`, `$OS_CODENAME`
- [ ] Vérification root si nécessaire
- [ ] Vérification compatibilité OS
- [ ] Fonctions d'affichage couleur
- [ ] Gestion d'erreur appropriée
- [ ] Backup des fichiers critiques avant modification
- [ ] Permissions correctes sur les fichiers créés
- [ ] Tests sur VM propre
- [ ] Syntaxe validée avec `bash -n`
- [ ] Commentaires pertinents
- [ ] `chmod +x script.sh` appliqué

---

## 📞 Support

Pour toute question sur ces bonnes pratiques :
- Consulter les scripts existants comme exemples
- Lire CLAUDE.md pour comprendre l'architecture
- Vérifier la documentation du launcher

**Auteur**: Eloïd DOPPEL - DoppelServices
**Version**: 1.0
**Dernière mise à jour**: 2025-11-14
