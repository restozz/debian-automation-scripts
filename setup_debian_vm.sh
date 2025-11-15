#!/bin/bash
# Description: Configuration post-installation Debian 13 (SSH, UFW, Fail2Ban)

################################################################################
# Script de configuration post-installation Debian 13
# Auteur: Eloïd DOPPEL
# Description: Automatise la mise à jour système et la configuration SSH sécurisée
################################################################################

set -e  # Arrêt du script en cas d'erreur

# Fichiers de log
TEMP_LOG="/tmp/debian_setup_debug_$(date +%Y%m%d_%H%M%S).log"
LOG_FILE="/var/log/debian_setup_$(date +%Y%m%d_%H%M%S).log"
ERROR_OCCURRED=0

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$TEMP_LOG"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[SUCCESS] $1" >> "$TEMP_LOG"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    echo "[WARNING] $1" >> "$TEMP_LOG"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[ERROR] $1" >> "$TEMP_LOG"
    ERROR_OCCURRED=1
}

print_debug() {
    echo "[DEBUG] $1" >> "$TEMP_LOG"
}

# Fonction de gestion d'erreur
handle_error() {
    local exit_code=$?
    local line_number=$1
    ERROR_OCCURRED=1
    print_error "Erreur à la ligne $line_number (code: $exit_code)"
    
    # Copier le log temporaire vers le fichier permanent
    cp "$TEMP_LOG" "$LOG_FILE"
    print_error "Log complet sauvegardé dans: $LOG_FILE"
    
    exit $exit_code
}

# Fonction de nettoyage à la sortie
cleanup() {
    if [ $ERROR_OCCURRED -eq 0 ]; then
        # Pas d'erreur, supprimer le log temporaire
        rm -f "$TEMP_LOG"
    else
        # Erreur, copier le log
        cp "$TEMP_LOG" "$LOG_FILE" 2>/dev/null || true
    fi
}

# Trap pour capturer les erreurs et le nettoyage
trap 'handle_error ${LINENO}' ERR
trap cleanup EXIT

# Récupérer les variables OS du launcher (si disponibles)
if [ -z "$OS_ID" ]; then
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_ID="$ID"
        OS_VERSION="${VERSION_ID:-unknown}"
        OS_CODENAME="${VERSION_CODENAME:-unknown}"
        OS_PRETTY_NAME="${PRETTY_NAME:-unknown}"
    else
        print_error "Impossible de détecter le système d'exploitation"
        exit 1
    fi
fi

# Vérification des privilèges root
print_debug "Vérification des privilèges root (EUID: $EUID)"
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

# Marqueur d'exécution
MARKER_DIR="/root/.debian-scripts"
MARKER_FILE="$MARKER_DIR/.debian_setup_installed"

# Vérifier si le script a déjà été exécuté
if [ -f "$MARKER_FILE" ]; then
    LAST_RUN=$(cat "$MARKER_FILE")
    echo ""
    echo -e "${YELLOW}⚠ ATTENTION${NC}"
    echo "Ce script a déjà été exécuté avec succès le: $LAST_RUN"
    echo ""
    read -p "Voulez-vous vraiment le relancer ? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation annulée."
        exit 0
    fi
    echo ""
fi

print_debug "Date: $(date), Utilisateur: $SUDO_USER, Système: $(uname -a)"
print_debug "OS: $OS_ID $OS_VERSION ($OS_CODENAME) - $OS_PRETTY_NAME"

# Vérifier la compatibilité (optionnel, pour l'instant on supporte principalement Debian)
if [[ "$OS_ID" != "debian" ]] && [[ "$OS_ID" != "ubuntu" ]]; then
    print_warning "Ce script est optimisé pour Debian/Ubuntu. OS détecté: $OS_ID"
    print_warning "Certaines commandes peuvent nécessiter des ajustements"
fi

# Clear de l'écran pour un affichage propre
clear

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Configuration post-installation Debian 13                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

################################################################################
# 1. Mise à jour du système
################################################################################
print_message "Étape 1/6: Mise à jour du système"
print_debug "Exécution: apt update"

echo -n "  [▓         ] 10% Mise à jour des dépôts..."
if ! apt update > "$TEMP_LOG" 2>&1; then
    echo -e "\r  [✗] Échec"
    print_error "Échec de la mise à jour des dépôts"
    exit 1
fi
echo -e "\r  [▓▓▓       ] 30% Mise à jour des dépôts... ✓"

echo -n "  [▓▓▓       ] 30% Installation des mises à jour..."
if ! apt upgrade -y >> "$TEMP_LOG" 2>&1; then
    echo -e "\r  [✗] Échec"
    print_error "Échec de la mise à niveau"
    exit 1
fi
echo -e "\r  [▓▓▓▓▓▓    ] 60% Installation des mises à jour... ✓"

echo -n "  [▓▓▓▓▓▓    ] 60% Mise à niveau distribution..."
apt dist-upgrade -y >> "$TEMP_LOG" 2>&1
echo -e "\r  [▓▓▓▓▓▓▓▓  ] 80% Mise à niveau distribution... ✓"

echo -n "  [▓▓▓▓▓▓▓▓  ] 80% Nettoyage..."
apt autoremove -y >> "$TEMP_LOG" 2>&1
apt autoclean >> "$TEMP_LOG" 2>&1
echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Nettoyage... ✓"

print_success "Système mis à jour"

################################################################################
# 2. Installation des paquets essentiels
################################################################################
print_message "Étape 2/6: Installation des paquets essentiels"

print_debug "Vérification OpenSSH: $(dpkg -l | grep openssh-server | awk '{print $3}')"

# Vérification si openssh-server est déjà installé
if dpkg -l | grep -q "^ii  openssh-server"; then
    print_debug "OpenSSH déjà installé"
    echo "  [✓] OpenSSH Server déjà installé"
else
    echo -n "  [▓▓        ] 20% OpenSSH Server..."
    if ! apt install -y openssh-server >> "$TEMP_LOG" 2>&1; then
        echo -e "\r  [✗] Échec"
        print_error "Échec installation OpenSSH"
        exit 1
    fi
    echo -e "\r  [✓] OpenSSH Server installé"
fi

# Vérification du service SSH
print_debug "Statut SSH: $(systemctl is-active ssh)"
if ! systemctl is-active --quiet ssh; then
    systemctl start ssh
    print_debug "Service SSH démarré"
fi

# Liste des paquets à installer
PACKAGES="vim nano curl wget git net-tools ufw fail2ban sudo"
TOTAL_PACKAGES=$(echo $PACKAGES | wc -w)

echo -n "  [          ] 0% Installation des paquets"

# Fonction d'animation en arrière-plan
(
    while true; do
        echo -n "."
        sleep 5
    done
) &
ANIM_PID=$!

# Installation
if apt install -y $PACKAGES >> "$TEMP_LOG" 2>&1; then
    kill $ANIM_PID 2>/dev/null || true
    wait $ANIM_PID 2>/dev/null || true
    echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation des paquets... ✓      "
    print_success "Paquets essentiels installés ($TOTAL_PACKAGES paquets)"
else
    kill $ANIM_PID 2>/dev/null || true
    wait $ANIM_PID 2>/dev/null || true
    echo -e "\r  [✗] Échec                                            "
    print_error "Échec installation paquets"
    exit 1
fi

################################################################################
# 3. Configuration de l'utilisateur et de la clé SSH
################################################################################
print_message "Étape 3/6: Configuration utilisateur et clé SSH"

# Demande du nom d'utilisateur
read -p "Nom d'utilisateur (défaut: $SUDO_USER): " USERNAME
USERNAME=${USERNAME:-$SUDO_USER}
print_debug "Utilisateur sélectionné: $USERNAME"

IS_ROOT=0
USER_CREATED=0

# Vérification si c'est root
if [ "$USERNAME" = "root" ]; then
    IS_ROOT=1
    print_warning "Configuration pour l'utilisateur root"
    print_debug "Mode root activé - PermitRootLogin sera configuré en prohibit-password"
else
    # Vérification de l'existence de l'utilisateur
    if ! id "$USERNAME" &>/dev/null; then
        print_message "L'utilisateur $USERNAME n'existe pas, création en cours..."
        print_debug "Création utilisateur: $USERNAME"
        
        # Création de l'utilisateur
        if ! adduser --gecos "" --disabled-password "$USERNAME" >> "$TEMP_LOG" 2>&1; then
            print_error "Échec de la création de l'utilisateur"
            exit 1
        fi
        
        # Ajout aux sudoers
        usermod -aG sudo "$USERNAME" >> "$TEMP_LOG" 2>&1
        print_success "Utilisateur $USERNAME créé (avec droits sudo)"
        USER_CREATED=1
    else
        print_debug "Utilisateur existant: $USERNAME (UID: $(id -u $USERNAME))"
        echo "  [✓] Utilisateur $USERNAME trouvé"
    fi
fi

# Configuration du répertoire .ssh
USER_HOME=$(eval echo ~$USERNAME)
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

print_debug "Home: $USER_HOME, SSH: $SSH_DIR"

if [ ! -d "$USER_HOME" ]; then
    print_error "Le répertoire home $USER_HOME n'existe pas"
    exit 1
fi

mkdir -p "$SSH_DIR"
touch "$AUTHORIZED_KEYS"

if [ ! -f "$AUTHORIZED_KEYS" ]; then
    print_error "Impossible de créer authorized_keys"
    exit 1
fi

# Demande de la clé SSH publique
echo ""
print_message "Clé SSH publique (ssh-rsa/ssh-ed25519):"
print_warning "Astuce: cat ~/.ssh/id_rsa.pub sur votre machine locale"
echo ""
read -p "Clé: " SSH_PUBLIC_KEY

print_debug "Longueur clé: ${#SSH_PUBLIC_KEY} caractères"

# Validation de la clé
if [[ ! "$SSH_PUBLIC_KEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
    print_error "Format de clé SSH invalide"
    print_debug "Doit commencer par: ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp..."
    exit 1
fi

# Vérification si la clé existe déjà
if grep -Fxq "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
    print_warning "Cette clé existe déjà"
else
    print_debug "Ajout clé dans $AUTHORIZED_KEYS"
    echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
    
    if [ $? -ne 0 ]; then
        print_error "Échec ajout clé SSH"
        exit 1
    fi
fi

# Configuration des permissions
print_debug "Permissions: 700 (.ssh), 600 (authorized_keys)"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"

# Vérification des permissions
PERMS_SSH=$(stat -c "%a" "$SSH_DIR")
PERMS_KEYS=$(stat -c "%a" "$AUTHORIZED_KEYS")
print_debug "Vérif permissions - SSH: $PERMS_SSH, Keys: $PERMS_KEYS"

if [ "$PERMS_SSH" != "700" ] || [ "$PERMS_KEYS" != "600" ]; then
    print_error "Permissions incorrectes"
    exit 1
fi

print_success "Clé SSH configurée pour $USERNAME"

################################################################################
# 4. Configuration sécurisée de SSH
################################################################################
print_message "Étape 4/6: Configuration SSH sécurisée"

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="$SSHD_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"

print_debug "Config: $SSHD_CONFIG, Backup: $BACKUP_FILE"

if [ ! -f "$SSHD_CONFIG" ]; then
    print_error "Fichier config SSH introuvable"
    exit 1
fi

cp "$SSHD_CONFIG" "$BACKUP_FILE"

if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Échec création backup"
    exit 1
fi

print_debug "Backup créé (taille: $(du -h $SSHD_CONFIG | awk '{print $1}'))"

# Déterminer la valeur de PermitRootLogin selon l'utilisateur
if [ $IS_ROOT -eq 1 ]; then
    ROOT_LOGIN_VALUE="prohibit-password"
    print_debug "Configuration PermitRootLogin: prohibit-password (clé SSH uniquement)"
else
    ROOT_LOGIN_VALUE="no"
    print_debug "Configuration PermitRootLogin: no (root complètement bloqué)"
fi

# Configuration SSH sécurisée avec PermitRootLogin adapté
cat > "$SSHD_CONFIG" << EOF
# Configuration SSH sécurisée - Générée automatiquement
# Port SSH personnalisé
Port 2000

# Protocole et chiffrement
Protocol 2
AddressFamily inet

# Authentification
PermitRootLogin $ROOT_LOGIN_VALUE
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Authentification par clé uniquement
AuthorizedKeysFile .ssh/authorized_keys

# Désactivation des méthodes d'authentification non sécurisées
KbdInteractiveAuthentication no
GSSAPIAuthentication no
HostbasedAuthentication no

# Sécurité réseau
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
PermitUserEnvironment no
AllowAgentForwarding yes
AllowTcpForwarding yes
PermitTunnel no

# Limites de connexion
MaxAuthTries 6
MaxSessions 10
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Subsystem SFTP
Subsystem sftp /usr/lib/openssh/sftp-server

# Algorithmes de chiffrement recommandés
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
EOF

print_success "Configuration SSH appliquée (PermitRootLogin: $ROOT_LOGIN_VALUE)"

################################################################################
# 5. Configuration du pare-feu UFW
################################################################################
print_message "Étape 5/6: Configuration pare-feu UFW"

print_debug "Reset UFW"
if ! ufw --force reset >> "$TEMP_LOG" 2>&1; then
    print_error "Échec reset UFW"
    exit 1
fi

print_debug "Règles par défaut"
ufw default deny incoming >> "$TEMP_LOG" 2>&1
ufw default allow outgoing >> "$TEMP_LOG" 2>&1

print_debug "Ajout port 2000"
if ! ufw allow 2000/tcp comment 'SSH personnalisé' >> "$TEMP_LOG" 2>&1; then
    print_error "Échec ajout règle port 2000"
    exit 1
fi

ufw logging on >> "$TEMP_LOG" 2>&1

print_debug "Activation UFW"
if ! ufw --force enable >> "$TEMP_LOG" 2>&1; then
    print_error "Échec activation UFW"
    exit 1
fi

# Vérification
print_debug "Statut UFW: $(ufw status | head -1)"
if ! ufw status | grep -q "Status: active"; then
    print_error "UFW non actif"
    exit 1
fi

print_success "Pare-feu UFW actif (port 2000 ouvert)"

################################################################################
# 6. Configuration de Fail2Ban
################################################################################
print_message "Étape 6/6: Configuration Fail2Ban"

print_debug "Création jail.local"

if ! cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 6
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = 2000
logpath = /var/log/auth.log
maxretry = 6
bantime = 3600
EOF
then
    print_error "Échec création config Fail2Ban"
    exit 1
fi

print_debug "Config créée: $(cat /etc/fail2ban/jail.local | wc -l) lignes"

if ! systemctl enable fail2ban >> "$TEMP_LOG" 2>&1; then
    print_error "Échec enable Fail2Ban"
    exit 1
fi

print_debug "Redémarrage Fail2Ban"
if ! systemctl restart fail2ban >> "$TEMP_LOG" 2>&1; then
    print_error "Échec restart Fail2Ban"
    print_debug "Voir: journalctl -xe -u fail2ban"
    exit 1
fi

sleep 2
if ! systemctl is-active --quiet fail2ban; then
    print_error "Fail2Ban non actif"
    exit 1
fi

print_success "Fail2Ban actif (6 tentatives max, ban 1h)"
print_debug "Jails: $(fail2ban-client status 2>/dev/null | grep 'Jail list' || echo 'sshd')"

################################################################################
# 7. Validation et redémarrage SSH
################################################################################
print_message "Validation configuration SSH"
print_debug "Test syntaxe: sshd -t"

if sshd -t >> "$TEMP_LOG" 2>&1; then
    print_success "Configuration SSH valide"
    
    print_debug "Restart SSH"
    if ! systemctl restart sshd >> "$TEMP_LOG" 2>&1; then
        print_error "Échec restart SSH"
        print_debug "Restauration backup..."
        cp "$BACKUP_FILE" "$SSHD_CONFIG"
        systemctl restart sshd
        exit 1
    fi
    
    # Enable SSH - ignorer l'erreur si déjà un lien symbolique
    print_debug "Enable SSH au démarrage"
    systemctl enable sshd >> "$TEMP_LOG" 2>&1 || true
    
    sleep 2
    if ! systemctl is-active --quiet sshd; then
        print_error "SSH non actif après restart"
        exit 1
    fi
    
    print_success "Service SSH redémarré"
    print_debug "Port écoute: $(ss -tlnp | grep :2000)"
else
    print_error "Config SSH invalide"
    print_debug "Restauration backup..."
    cp "$BACKUP_FILE" "$SSHD_CONFIG"
    systemctl restart sshd
    exit 1
fi

################################################################################
# Récapitulatif
################################################################################
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ✓ Configuration terminée avec succès             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Récapitulatif:"
echo "  • Utilisateur SSH: $USERNAME"
if [ $USER_CREATED -eq 1 ]; then
    echo "    └─ Utilisateur créé avec droits sudo"
fi
if [ $IS_ROOT -eq 1 ]; then
    echo "    └─ Mode root: clé SSH uniquement (prohibit-password)"
fi
echo "  • Port SSH: 2000"
echo "  • Auth mot de passe: DÉSACTIVÉE"
echo "  • Auth par clé: ACTIVÉE"
echo "  • Pare-feu UFW: ACTIF (port 2000)"
echo "  • Fail2Ban: ACTIF (6 tentatives, ban 1h)"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT - TESTEZ AVANT DE DÉCONNECTER:${NC}"
echo ""
echo "  Dans un NOUVEAU terminal:"
echo "  ssh -p 2000 $USERNAME@$(hostname -I | awk '{print $1}')"
echo ""
echo "  Si échec, restaurez depuis ce terminal:"
echo "  cp $BACKUP_FILE $SSHD_CONFIG && systemctl restart sshd"
echo ""
echo "Connexion:"
echo "  IP: $(hostname -I | awk '{print $1}')"
echo "  Port: 2000"
echo "  User: $USERNAME"
echo ""
echo "Système: $(lsb_release -ds) | Kernel: $(uname -r)"
print_debug "Script terminé - $(date)"

# Créer le marqueur d'exécution réussie
mkdir -p "$MARKER_DIR"
date '+%Y-%m-%d %H:%M:%S' > "$MARKER_FILE"

echo ""
