#!/bin/bash
# Description: Installation complète de Docker et Docker Compose

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() { echo -e "${BLUE}[→]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root"
   exit 1
fi

# Récupérer les variables OS du launcher (si disponibles)
if [ -z "$OS_ID" ]; then
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_ID="$ID"
        OS_VERSION="${VERSION_ID:-unknown}"
        OS_CODENAME="${VERSION_CODENAME:-unknown}"
    else
        print_error "Impossible de détecter le système d'exploitation"
        exit 1
    fi
fi

# Vérifier la compatibilité
if [[ "$OS_ID" != "debian" ]] && [[ "$OS_ID" != "ubuntu" ]]; then
    print_error "Ce script supporte uniquement Debian et Ubuntu"
    print_error "OS détecté: $OS_ID"
    exit 1
fi

# Marqueur d'exécution
MARKER_DIR="/root/.debian-scripts"
MARKER_FILE="$MARKER_DIR/.docker_installed"

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

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Installation Docker & Docker Compose              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_message "Système: $OS_ID $OS_VERSION ($OS_CODENAME)"
echo ""

print_message "Mise à jour du système"
apt-get update -qq

print_message "Installation des prérequis"
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release > /dev/null 2>&1

print_message "Ajout de la clé GPG Docker"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

print_message "Ajout du dépôt Docker"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
  $OS_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

print_message "Installation de Docker"
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

print_message "Démarrage de Docker"
systemctl enable docker
systemctl start docker

print_success "Docker installé avec succès"
echo ""
docker --version
docker compose version
echo ""
print_message "Test Docker"
docker run --rm hello-world

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Installation terminée                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Commandes utiles:"
echo "  docker ps              - Liste des conteneurs actifs"
echo "  docker compose up -d   - Lancer des services"
echo "  docker logs <nom>      - Voir les logs"
echo ""

# Créer le marqueur d'exécution réussie
mkdir -p "$MARKER_DIR"
date '+%Y-%m-%d %H:%M:%S' > "$MARKER_FILE"
