#!/bin/bash

################################################################################
# Script Launcher - Hub centralisé pour scripts système
# Auteur: Felix
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
SCRIPT_DIR="$LAUNCHER_DIR/scripts"
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

# Vérification/installation de git
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${BLUE}[→]${NC} Installation de Git..."
        apt-get update -qq && apt-get install -y git
        echo -e "${GREEN}[✓]${NC} Git installé"
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
    
    GITHUB_REPO="$repo_url"
    
    # Nettoyer l'ancien dépôt si existant
    if [ -d "$SCRIPT_DIR" ]; then
        rm -rf "$SCRIPT_DIR"
    fi
    
    echo -e "${BLUE}[→]${NC} Clonage du dépôt..."
    if git clone "$GITHUB_REPO" "$SCRIPT_DIR" 2>/dev/null; then
        save_config
        echo -e "${GREEN}[✓]${NC} Dépôt cloné avec succès"
        sleep 2
        return 0
    else
        echo -e "${RED}[✗]${NC} Échec du clonage"
        sleep 2
        return 1
    fi
}

# Mise à jour du dépôt GitHub
update_github_repo() {
    if [ -z "$GITHUB_REPO" ] || [ ! -d "$SCRIPT_DIR/.git" ]; then
        whiptail --title "Configuration requise" --msgbox "Aucun dépôt configuré.\n\nVeuillez d'abord configurer un dépôt GitHub." 10 50
        setup_github_repo
        return $?
    fi
    
    echo -e "${BLUE}[→]${NC} Mise à jour depuis GitHub..."
    cd "$SCRIPT_DIR"
    
    if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
        save_config
        echo -e "${GREEN}[✓]${NC} Scripts mis à jour"
        sleep 2
        return 0
    else
        echo -e "${RED}[✗]${NC} Échec de la mise à jour"
        sleep 2
        return 1
    fi
}

# Création du répertoire scripts s'il n'existe pas
init_dirs() {
    mkdir -p "$SCRIPT_DIR"
}

# Fonction pour charger les scripts disponibles
load_scripts() {
    declare -a SCRIPTS
    declare -a DESCRIPTIONS
    
    # Script 1: Configuration Debian (toujours présent en local)
    if [ -f "$LAUNCHER_DIR/setup_debian_vm.sh" ]; then
        SCRIPTS[0]="$LAUNCHER_DIR/setup_debian_vm.sh"
        DESCRIPTIONS[0]="Configuration post-installation Debian 13"
    fi
    
    # Charger les scripts depuis GitHub
    local index=1
    if [ -d "$SCRIPT_DIR" ]; then
        # Chercher les fichiers .sh dans le dépôt
        for script in "$SCRIPT_DIR"/*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                local script_name=$(basename "$script")
                # Lire la description depuis la première ligne de commentaire
                local desc=$(head -n 5 "$script" | grep -m1 "^# Description:" | sed 's/^# Description: //' || echo "Script: $script_name")
                
                SCRIPTS[$index]="$script"
                DESCRIPTIONS[$index]="$desc"
                ((index++))
            fi
        done
        
        # Chercher aussi dans un dossier scripts/ si présent
        if [ -d "$SCRIPT_DIR/scripts" ]; then
            for script in "$SCRIPT_DIR/scripts"/*.sh; do
                if [ -f "$script" ] && [ -x "$script" ]; then
                    local script_name=$(basename "$script")
                    local desc=$(head -n 5 "$script" | grep -m1 "^# Description:" | sed 's/^# Description: //' || echo "Script: $script_name")
                    
                    SCRIPTS[$index]="$script"
                    DESCRIPTIONS[$index]="$desc"
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
    menu_items+=("U" "Mettre à jour depuis GitHub")
    menu_items+=("Q" "Quitter")
    
    # Afficher l'info sur le dépôt actuel
    local repo_info=""
    if [ -n "$GITHUB_REPO" ]; then
        repo_info="\n\nDépôt actuel: $(basename "$GITHUB_REPO" .git)"
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
    local script_path="${SCRIPT_LIST[$script_index]}"
    
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
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    read -p "Appuyez sur Entrée pour revenir au menu..."
}

# Fonction principale
main() {
    check_root
    check_whiptail
    check_git
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
            U|u)
                clear
                update_github_repo
                ;;
            Q|q|"")
                clear
                echo -e "${GREEN}[✓]${NC} Au revoir!"
                exit 0
                ;;
            *)
                whiptail --title "Erreur" --msgbox "Option invalide" 8 40
                ;;
        esac
    done
}

main
