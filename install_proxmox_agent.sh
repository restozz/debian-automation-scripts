#!/bin/bash
# Description: Installation QEMU Guest Agent pour Proxmox VE

################################################################################
# Script d'installation QEMU Guest Agent pour Proxmox
# Auteur: Eloïd DOPPEL
# Description: Détecte et installe automatiquement qemu-guest-agent
# Compatible: Debian, Ubuntu, RHEL, CentOS, Rocky, Alma, Fedora, openSUSE, Arch, Alpine
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Fichier de log temporaire
TEMP_LOG="/tmp/proxmox_agent_install_$(date +%Y%m%d_%H%M%S).log"

# Fonctions d'affichage
print_message() {
    echo -e "${BLUE}[→]${NC} $1"
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
}

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root"
   exit 1
fi

# Marqueur d'exécution
MARKER_DIR="/root/.debian-scripts"
MARKER_FILE="$MARKER_DIR/.proxmox_agent_installed"

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

# Clear de l'écran pour un affichage propre
clear

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Installation QEMU Guest Agent pour Proxmox            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_message "Système: $OS_PRETTY_NAME"
echo ""

################################################################################
# Étape 1: Vérification de la distribution
################################################################################
print_message "Étape 1/3: Vérification de la compatibilité"

# Liste des distributions supportées
SUPPORTED_DISTROS="debian ubuntu linuxmint pop rhel centos rocky almalinux ol fedora opensuse opensuse-leap opensuse-tumbleweed sles arch manjaro alpine"

if [[ ! " $SUPPORTED_DISTROS " =~ " $OS_ID " ]]; then
    print_error "Distribution non supportée: $OS_ID"
    echo ""
    echo -e "${YELLOW}Distributions supportées:${NC}"
    echo "  • Debian, Ubuntu, Linux Mint, Pop!_OS"
    echo "  • RHEL, CentOS, Rocky Linux, AlmaLinux, Oracle Linux"
    echo "  • Fedora"
    echo "  • openSUSE (Leap, Tumbleweed), SLES"
    echo "  • Arch Linux, Manjaro"
    echo "  • Alpine Linux"
    echo ""
    exit 1
fi

print_success "Distribution supportée: $OS_ID"
echo ""

################################################################################
# Étape 2: Installation de QEMU Guest Agent
################################################################################
print_message "Étape 2/3: Installation de QEMU Guest Agent"

echo -n "  [          ] 0% Préparation..."

# Installation selon la distribution
case $OS_ID in
    ubuntu|debian|linuxmint|pop)
        echo -e "\r  [▓▓        ] 20% Mise à jour des dépôts..."
        apt-get update >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓     ] 50% Installation du paquet..."
        apt-get install -y qemu-guest-agent >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation terminée ✓"
        ;;

    rhel|centos|rocky|almalinux|ol)
        echo -e "\r  [▓▓▓▓▓     ] 50% Installation du paquet..."
        if command -v dnf &> /dev/null; then
            dnf install -y qemu-guest-agent >> "$TEMP_LOG" 2>&1
        else
            yum install -y qemu-guest-agent >> "$TEMP_LOG" 2>&1
        fi

        echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation terminée ✓"
        ;;

    fedora)
        echo -e "\r  [▓▓▓▓▓     ] 50% Installation du paquet..."
        dnf install -y qemu-guest-agent >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation terminée ✓"
        ;;

    opensuse|opensuse-leap|opensuse-tumbleweed|sles)
        echo -e "\r  [▓▓▓▓▓     ] 50% Installation du paquet..."
        zypper install -y qemu-guest-agent >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation terminée ✓"
        ;;

    arch|manjaro)
        echo -e "\r  [▓▓        ] 20% Synchronisation..."
        pacman -Sy --noconfirm >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓     ] 50% Installation du paquet..."
        pacman -S --noconfirm qemu-guest-agent >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation terminée ✓"
        ;;

    alpine)
        echo -e "\r  [▓▓▓▓▓     ] 50% Installation du paquet..."
        apk add qemu-guest-agent >> "$TEMP_LOG" 2>&1

        echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Installation terminée ✓"
        ;;

    *)
        print_error "Erreur interne: distribution non gérée"
        exit 1
        ;;
esac

print_success "QEMU Guest Agent installé"
echo ""

################################################################################
# Étape 3: Configuration et démarrage du service
################################################################################
print_message "Étape 3/3: Configuration du service"

echo -n "  [          ] 0% Activation du service..."

# Activation du service au démarrage
if systemctl enable qemu-guest-agent >> "$TEMP_LOG" 2>&1; then
    echo -e "\r  [▓▓▓▓▓     ] 50% Service activé..."
else
    echo -e "\r  [✗] Échec activation du service"
    print_error "Impossible d'activer le service"
    exit 1
fi

# Démarrage du service
if systemctl start qemu-guest-agent >> "$TEMP_LOG" 2>&1; then
    echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Service démarré ✓    "
    print_success "Service qemu-guest-agent actif"
else
    echo -e "\r  [▓▓▓▓▓▓▓▓▓▓] 100% Service activé (nécessite redémarrage)    "
    print_warning "Le service ne démarre pas (matériel virtuel non détecté)"
    print_message "Un REDÉMARRAGE de la VM est nécessaire pour activer l'agent"
fi
echo ""

################################################################################
# Vérification finale
################################################################################
print_message "Vérification finale"

if systemctl is-active --quiet qemu-guest-agent; then
    print_success "QEMU Guest Agent fonctionne correctement"
else
    print_warning "Service installé mais pas encore actif"
    print_message "Le service sera actif après redémarrage de la VM"
fi

# Récapitulatif
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              ✓ Installation terminée avec succès              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}📋 ÉTAPES SUIVANTES:${NC}"
echo ""
echo -e "${CYAN}1. Activer l'agent dans Proxmox (si pas déjà fait):${NC}"
echo ""
echo "   Option A - Interface Web:"
echo "     • VM → Options → QEMU Guest Agent → ✓ Activer"
echo ""
echo "   Option B - Ligne de commande:"
echo "     • qm set <VMID> --agent 1"
echo ""
echo -e "${RED}2. ⚠ REDÉMARRER LA VM (obligatoire):${NC}"
echo -e "${YELLOW}   reboot${NC}"
echo ""
echo -e "${GREEN}3. Après redémarrage, vérifier:${NC}"
echo "   systemctl status qemu-guest-agent"
echo ""
echo "Commandes utiles:"
echo "  systemctl status qemu-guest-agent   - Vérifier le statut"
echo "  journalctl -u qemu-guest-agent      - Voir les logs"
echo ""
echo "Système: $OS_PRETTY_NAME"
echo "Log: $TEMP_LOG"
echo ""

################################################################################
# Marqueur d'exécution réussie
################################################################################
mkdir -p "$MARKER_DIR"
date '+%Y-%m-%d %H:%M:%S' > "$MARKER_FILE"

################################################################################
# Proposition de redémarrage
################################################################################
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Voulez-vous redémarrer la VM maintenant pour activer l'agent ?${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
read -p "Redémarrer maintenant ? (y/N) " -n 1 -r
echo ""
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}⚠ Redémarrage de la VM dans 5 secondes...${NC}"
    echo ""
    sleep 1
    echo "  5..."
    sleep 1
    echo "  4..."
    sleep 1
    echo "  3..."
    sleep 1
    echo "  2..."
    sleep 1
    echo "  1..."
    sleep 1
    echo ""
    echo -e "${GREEN}Redémarrage en cours...${NC}"
    reboot
else
    echo -e "${BLUE}[→]${NC} Redémarrage annulé"
    echo -e "${YELLOW}N'oubliez pas de redémarrer la VM plus tard avec: ${NC}${RED}reboot${NC}"
    echo ""
fi
