#!/bin/bash
# Description: Installation complète de Docker et Docker Compose

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() { echo -e "${BLUE}[→]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root"
   exit 1
fi

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Installation Docker & Docker Compose              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
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
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

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
