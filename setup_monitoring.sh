#!/bin/bash
# Description: Installation et configuration Zabbix Agent 6.x

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() { echo -e "${BLUE}[→]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root"
   exit 1
fi

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            Installation Zabbix Agent 6.x                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Demande de l'IP du serveur Zabbix
read -p "Adresse IP du serveur Zabbix: " ZABBIX_SERVER
read -p "Hostname de cette machine (défaut: $(hostname)): " ZABBIX_HOSTNAME
ZABBIX_HOSTNAME=${ZABBIX_HOSTNAME:-$(hostname)}

print_message "Installation du dépôt Zabbix"
wget https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian$(lsb_release -sr)_all.deb
dpkg -i zabbix-release_6.4-1+debian$(lsb_release -sr)_all.deb
rm zabbix-release_6.4-1+debian$(lsb_release -sr)_all.deb

print_message "Installation Zabbix Agent"
apt-get update -qq
apt-get install -y zabbix-agent2 zabbix-agent2-plugin-* > /dev/null 2>&1

print_message "Configuration Zabbix Agent"
cat > /etc/zabbix/zabbix_agent2.conf << EOF
Server=$ZABBIX_SERVER
ServerActive=$ZABBIX_SERVER
Hostname=$ZABBIX_HOSTNAME
EOF

print_message "Démarrage Zabbix Agent"
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2

print_success "Zabbix Agent installé et configuré"
echo ""
echo "Configuration:"
echo "  Serveur: $ZABBIX_SERVER"
echo "  Hostname: $ZABBIX_HOSTNAME"
echo "  Port: 10050"
echo ""
systemctl status zabbix-agent2 --no-pager | head -5
echo ""
