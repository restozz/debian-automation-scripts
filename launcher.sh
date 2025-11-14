#!/bin/bash

################################################################################
# Script Launcher - Hub centralisé pour scripts système
# Auteur: Felix
# Description: Télécharge et exécute les scripts à la demande depuis GitHub
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Répertoires et fichiers
LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$LAUNCHER_DIR/.temp_scripts"
CONFIG_FILE="$LAUNCHER_DIR/.launcher_config"

# Vérification des privilèges root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[✗]${NC} Ce launcher doit être exécuté en root (sudo)"
        exit 1
    fi
}

# Vérification/installation de whiptail
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        echo "Installation de whiptail..."
        apt-get update -qq && apt-get install -y whiptail
    fi
}

# Vérification/installation de curl
check_curl() {
    if ! command -v curl &> /dev/null; then
        echo -e "${BLUE}[→]${NC} Installation de curl..."
        apt-get update -qq && apt-get install -y curl
        echo -e "${GREEN}[✓]${NC} curl installé"
    fi
}

# Charger la configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Sauvegarder la configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
GITHUB_REPO="$GITHUB_REPO"
GITHUB_USER="$GITHUB_USER"
GITHUB_REPO_NAME="$GITHUB_REPO_NAME"
GITHUB_BRANCH="$GITHUB_BRANCH"
LAST_UPDATE=$(date +%s)
EOF
}

# Configuration initiale du dépôt GitHub
setup_github_repo() {
    local repo_url

    repo_url=$(whiptail --inputbox "URL du dépôt GitHub:\n(ex: https://github.com/user/repo.git)" 10 70 "${GITHUB_REPO}" 3>&1 1>&2 2>&3)

    if [ -z "$repo_url" ]; then
        return 1
    fi

    # Extraire user et repo depuis l'URL
    # Format: https://github.com/user/repo.git
    GITHUB_REPO="$repo_url"
    GITHUB_USER=$(echo "$repo_url" | sed -n 's#.*github.com/\([^/]*\)/.*#\1#p')
    GITHUB_REPO_NAME=$(echo "$repo_url" | sed -n 's#.*github.com/[^/]*/\([^.]*\).*#\1#p')
    GITHUB_BRANCH="main"

    if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO_NAME" ]; then
        echo -e "${RED}[✗]${NC} Format d'URL invalide"
        sleep 2
        return 1
    fi

    # Test de connexion au dépôt
    echo -e "${BLUE}[→]${NC} Vérification du dépôt..."
    local test_url="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO_NAME"
    if curl -s -f "$test_url" > /dev/null 2>&1; then
        save_config
        echo -e "${GREEN}[✓]${NC} Dépôt configuré avec succès"
        sleep 2
        return 0
    else
        # Essayer avec la branche master
        GITHUB_BRANCH="master"
        if curl -s -f "$test_url" > /dev/null 2>&1; then
            save_config
            echo -e "${GREEN}[✓]${NC} Dépôt configuré avec succès"
            sleep 2
            return 0
        else
            echo -e "${RED}[✗]${NC} Impossible d'accéder au dépôt"
            sleep 2
            return 1
        fi
    fi
}

# Lister les scripts disponibles sur GitHub
list_github_scripts() {
    if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO_NAME" ]; then
        return 1
    fi

    # URL de l'API GitHub pour lister les fichiers
    local api_url="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO_NAME/contents"

    # Récupérer la liste des fichiers .sh
    GITHUB_SCRIPTS=$(curl -s "$api_url" | grep -o '"name": "[^"]*\.sh"' | sed 's/"name": "\(.*\)"/\1/' || echo "")
}

# Télécharger un script depuis GitHub
download_script() {
    local script_name=$1
    local download_url="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO_NAME/$GITHUB_BRANCH/$script_name"
    local temp_file="$TEMP_DIR/$script_name"

    mkdir -p "$TEMP_DIR"

    echo -e "${BLUE}[→]${NC} Téléchargement de $script_name..."
    if curl -s -f "$download_url" -o "$temp_file" 2>/dev/null; then
        chmod +x "$temp_file"
        echo -e "${GREEN}[✓]${NC} Script téléchargé"
        return 0
    else
        echo -e "${RED}[✗]${NC} Échec du téléchargement"
        return 1
    fi
}

# Extraire la description d'un script depuis GitHub
get_script_description() {
    local script_name=$1
    local download_url="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO_NAME/$GITHUB_BRANCH/$script_name"

    # Télécharger les 5 premières lignes et extraire la description
    local desc=$(curl -s "$download_url" | head -n 5 | grep -m1 "^# Description:" | sed 's/^# Description: //' || echo "Script: $script_name")
    echo "$desc"
}

# Fonction pour charger les scripts disponibles
load_scripts() {
    declare -a SCRIPTS
    declare -a DESCRIPTIONS
    local index=0

    # Script 1: Configuration Debian (toujours présent en local)
    if [ -f "$LAUNCHER_DIR/setup_debian_vm.sh" ]; then
        SCRIPTS[$index]="local:setup_debian_vm.sh"
        DESCRIPTIONS[$index]="Configuration post-installation Debian 13 (Local)"
        ((index++))
    fi

    # Script 2: Installation Docker (toujours présent en local)
    if [ -f "$LAUNCHER_DIR/install_docker.sh" ]; then
        SCRIPTS[$index]="local:install_docker.sh"
        DESCRIPTIONS[$index]="Installation complète de Docker et Docker Compose (Local)"
        ((index++))
    fi

    # Charger les scripts depuis GitHub
    if [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_REPO_NAME" ]; then
        list_github_scripts

        if [ -n "$GITHUB_SCRIPTS" ]; then
            for script_name in $GITHUB_SCRIPTS; do
                # Ignorer les scripts déjà présents localement
                if [ "$script_name" != "setup_debian_vm.sh" ] && [ "$script_name" != "install_docker.sh" ]; then
                    local desc=$(get_script_description "$script_name")
                    SCRIPTS[$index]="github:$script_name"
                    DESCRIPTIONS[$index]="$desc (GitHub)"
                    ((index++))
                fi
            done
        fi
    fi

    # Retourner les arrays
    export SCRIPT_LIST=("${SCRIPTS[@]}")
    export DESC_LIST=("${DESCRIPTIONS[@]}")
    export SCRIPT_COUNT=${#SCRIPTS[@]}
}

# Construire le menu whiptail
build_menu() {
    local menu_items=()

    for i in "${!SCRIPT_LIST[@]}"; do
        menu_items+=("$((i+1))" "${DESC_LIST[$i]}")
    done

    # Ajouter les options système
    menu_items+=("" "")
    menu_items+=("G" "Configurer dépôt GitHub")
    menu_items+=("R" "Rafraîchir la liste des scripts")
    menu_items+=("Q" "Quitter")

    # Afficher l'info sur le dépôt actuel
    local repo_info=""
    if [ -n "$GITHUB_REPO" ]; then
        repo_info="\n\nDépôt: $GITHUB_USER/$GITHUB_REPO_NAME"
    fi

    CHOICE=$(whiptail --title "🚀 Script Launcher - Hub Système" \
        --menu "Sélectionnez un script à exécuter:$repo_info" \
        22 78 14 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3)
}

# Exécuter le script sélectionné
execute_script() {
    local script_index=$((CHOICE-1))
    local script_info="${SCRIPT_LIST[$script_index]}"

    # Extraire le type et le nom du script
    local script_type=$(echo "$script_info" | cut -d: -f1)
    local script_name=$(echo "$script_info" | cut -d: -f2)

    local script_path=""

    if [ "$script_type" = "local" ]; then
        # Script local
        script_path="$LAUNCHER_DIR/$script_name"
    else
        # Script GitHub - télécharger d'abord
        if download_script "$script_name"; then
            script_path="$TEMP_DIR/$script_name"
        else
            sleep 2
            return 1
        fi
    fi

    if [ ! -f "$script_path" ]; then
        whiptail --title "Erreur" --msgbox "Script introuvable: $script_path" 8 60
        return 1
    fi

    chmod +x "$script_path"

    clear
    echo -e "${BLUE}[→]${NC} Exécution: ${DESC_LIST[$script_index]}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    bash "$script_path"

    # Nettoyer le script temporaire si c'était un script GitHub
    if [ "$script_type" = "github" ]; then
        rm -f "$script_path"
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    read -p "Appuyez sur Entrée pour revenir au menu..."
}

# Fonction principale
main() {
    check_root
    check_whiptail
    check_curl
    load_config

    # Vérifier si le dépôt est configuré au premier lancement
    if [ -z "$GITHUB_REPO" ]; then
        if whiptail --title "Configuration initiale" --yesno "Aucun dépôt GitHub configuré.\n\nVoulez-vous configurer un dépôt maintenant?" 10 60; then
            setup_github_repo
        fi
    fi

    while true; do
        load_scripts

        if ! build_menu; then
            # Utilisateur a annulé (ESC)
            exit 0
        fi

        case "$CHOICE" in
            [1-9]|[1-9][0-9])
                execute_script
                ;;
            G|g)
                clear
                setup_github_repo
                ;;
            R|r)
                clear
                echo -e "${BLUE}[→]${NC} Rafraîchissement de la liste..."
                sleep 1
                ;;
            Q|q|"")
                clear
                echo -e "${GREEN}[✓]${NC} Au revoir!"
                # Nettoyer le dossier temporaire
                rm -rf "$TEMP_DIR"
                exit 0
                ;;
            *)
                whiptail --title "Erreur" --msgbox "Option invalide" 8 40
                ;;
        esac
    done
}

main
