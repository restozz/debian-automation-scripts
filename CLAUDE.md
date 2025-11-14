# CLAUDE.md - AI Assistant Guide

**Repository**: debian-automation-scripts
**Language**: French (scripts and documentation)
**Purpose**: System automation scripts for Debian infrastructure with launcher-based deployment
**Author**: Eloïd DOPPEL (DoppelServices)
**License**: BSD 2-Clause (see LICENSE)

---

## 📋 Table of Contents

1. [Repository Overview](#repository-overview)
2. [Codebase Structure](#codebase-structure)
3. [Scripts Deep Dive](#scripts-deep-dive)
4. [Development Workflows](#development-workflows)
5. [Code Conventions](#code-conventions)
6. [Testing & Validation](#testing--validation)
7. [Security Considerations](#security-considerations)
8. [Common AI Assistant Tasks](#common-ai-assistant-tasks)
9. [Troubleshooting Guide](#troubleshooting-guide)

---

## 🎯 Repository Overview

### Purpose
This repository provides a centralized launcher system for Debian automation scripts. It's designed for:
- **System administrators** managing multiple Debian servers
- **Infrastructure automation** in multi-site environments (UniFi SD-WAN)
- **Post-installation configuration** of Debian 13 systems
- **Standardized deployments** via GitHub-based script distribution

### Architecture Pattern
**Launcher Hub Model**: A central launcher script (`launcher.sh`) pulls automation scripts from GitHub and presents them in an interactive menu using `whiptail`.

### Key Features
- Interactive TUI menu with whiptail
- GitHub repository integration for script updates
- Automatic script discovery and menu generation
- Root privilege management
- Color-coded console output
- Comprehensive error handling and logging

---

## 📁 Codebase Structure

```
debian-automation-scripts/
├── LICENSE                    # BSD 2-Clause License
├── README.md                  # User-facing documentation (French)
├── INSTRUCTIONS.md            # Quick deployment guide
├── SETUP_GUIDE.md            # Detailed GitHub setup instructions
├── CLAUDE.md                 # This file - AI assistant guide
├── BONNES_PRATIQUES.md       # Best practices for script development
│
├── launcher.sh               # Main launcher hub (~400 lines)
│   ├── Menu system (whiptail)
│   ├── GitHub API integration
│   ├── OS detection system
│   └── On-demand script download & execution
│
└── Automation Scripts:
    ├── setup_debian_vm.sh      # Post-install config (~560 lines)
    ├── install_docker.sh       # Docker installation (~90 lines)
    └── install_proxmox_agent.sh # Proxmox Agent (~200 lines)

Runtime Generated:
├── .launcher_config          # Generated: Stores GitHub repo + OS info
└── .temp_scripts/            # Generated: Temporary folder for downloaded scripts
```

### File Descriptions

| File | Lines | Purpose | Key Functions |
|------|-------|---------|---------------|
| `launcher.sh` | ~400 | Main hub | `setup_github_repo()`, `download_script()`, `detect_os()` |
| `setup_debian_vm.sh` | ~560 | SSH hardening | User setup, SSH config, UFW, Fail2Ban |
| `install_docker.sh` | ~90 | Docker setup | Install Docker CE + Compose with OS detection |
| `install_proxmox_agent.sh` | ~200 | Proxmox Agent | Install QEMU Guest Agent (multi-distro) |
| `BONNES_PRATIQUES.md` | - | Guidelines | Best practices for script development |

---

## 🔧 Scripts Deep Dive

### 1. launcher.sh (Hub System)

**Purpose**: Central menu system for on-demand script download and execution

**Key Components**:
```bash
# Directory structure
LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$LAUNCHER_DIR/.temp_scripts"  # Temporary download location
CONFIG_FILE="$LAUNCHER_DIR/.launcher_config"

# Main workflow
check_root() → check_curl() → load_config() → detect_os() → main_loop()
```

**Détection du système d'exploitation**:

Le launcher détecte automatiquement le système au démarrage et expose ces variables à tous les scripts :

```bash
OS_ID           # Identifiant de la distribution (ex: "debian", "ubuntu")
OS_VERSION      # Version de la distribution (ex: "13", "24.04")
OS_CODENAME     # Nom de code (ex: "trixie", "bookworm", "noble")
OS_PRETTY_NAME  # Nom complet (ex: "Debian GNU/Linux 13 (trixie)")
```

Ces variables sont :
1. Détectées depuis `/etc/os-release`
2. Sauvegardées dans `.launcher_config`
3. Exportées avant chaque exécution de script
4. Disponibles pour tous les scripts via les variables d'environnement

**Architecture** - Téléchargement à la demande:
1. Affiche les scripts locaux (setup_debian_vm.sh, install_docker.sh)
2. Utilise l'API GitHub pour lister les scripts disponibles sur le dépôt
3. Télécharge le script uniquement quand l'utilisateur le sélectionne
4. Exécute le script puis le supprime du cache temporaire

**Script Discovery Logic** (lines 156-196):
1. Scripts locaux toujours disponibles (marqués "Local")
2. Liste les scripts `.sh` via GitHub API
3. Récupère la description de chaque script depuis GitHub
4. Exclut les doublons (scripts déjà présents localement)

**GitHub Integration**:
- `G` key: Configurer l'URL du dépôt GitHub
- `R` key: Rafraîchir la liste des scripts
- Utilise l'API GitHub pour lister les fichiers
- Télécharge via raw.githubusercontent.com
- Supporte les branches `main` et `master`
- **Authentification automatique** pour dépôts privés :
  - Détecte si le dépôt est privé
  - Demande un Personal Access Token (PAT)
  - Token stocké de manière sécurisée (chmod 600)
  - Utilisé pour toutes les requêtes API et téléchargements

**Menu System**: Uses whiptail for TUI with 22x78 character window

**Avantages du téléchargement à la demande**:
- Pas besoin de cloner tout le dépôt
- Scripts toujours à jour (téléchargés à chaque exécution)
- Économie d'espace disque
- Pas de gestion de git pull

**Configuration dépôt privé**:

Pour utiliser un dépôt GitHub privé, vous devez créer un Personal Access Token :

1. GitHub → Settings → Developer settings
2. Personal access tokens → Tokens (classic)
3. Generate new token (classic)
4. Sélectionner les permissions : **repo** (Full control of private repositories)
5. Copier le token généré
6. Le fournir au launcher lors de la configuration

Le token est stocké dans `.launcher_config` avec permissions 600 (lecture/écriture propriétaire uniquement).

### 2. setup_debian_vm.sh (Security Hardening)

**Purpose**: Post-installation security configuration for Debian 13

**Execution Steps** (6 phases):
1. **System Update** (lines 98-129): `apt update/upgrade/dist-upgrade/autoremove`
2. **Package Installation** (lines 130-186): OpenSSH, vim, curl, ufw, fail2ban, etc.
3. **User & SSH Key** (lines 187-293): Create user, configure authorized_keys
4. **SSH Hardening** (lines 294-385): Secure sshd_config, port 2000, key-only auth
5. **UFW Firewall** (lines 386-423): Enable with port 2000 only
6. **Fail2Ban** (lines 424-474): Configure SSH protection (6 attempts, 1h ban)

**Special Features**:
- **Root mode detection**: Allows `PermitRootLogin prohibit-password` if configuring for root
- **Progress indicators**: Visual progress bars for long operations
- **Comprehensive logging**: Temp log → permanent log on error
- **Backup creation**: Automatic sshd_config backup before changes
- **Validation**: Tests SSH config with `sshd -t` before applying

**Configuration Generated**:
```bash
Port 2000                          # Custom SSH port
PasswordAuthentication no          # Key-only authentication
PermitRootLogin no/prohibit-password  # Based on user choice
UFW: Allow 2000/tcp               # Firewall rule
Fail2Ban: maxretry=6, bantime=3600  # Intrusion prevention
```

**Error Handling**:
- `set -e`: Exit on any error
- `trap 'handle_error ${LINENO}' ERR`: Capture errors with line numbers
- Detailed debug logging to `/tmp/debian_setup_debug_*.log`

### 3. install_docker.sh (Container Platform)

**Purpose**: Install Docker Engine and Docker Compose plugin

**Process**:
1. Add Docker GPG key to `/etc/apt/keyrings/docker.gpg`
2. Configure Docker APT repository for Debian
3. Install: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`
4. Enable and start Docker service
5. Verify with `docker run --rm hello-world`

**Silent Mode**: Most output redirected to `/dev/null` for clean display

### 4. install_proxmox_agent.sh (Proxmox Guest Agent)

**Purpose**: Install QEMU Guest Agent for Proxmox VE integration

**Multi-distribution support**:
- Debian, Ubuntu, Linux Mint, Pop!_OS
- RHEL, CentOS, Rocky Linux, AlmaLinux, Oracle Linux
- Fedora
- openSUSE (Leap, Tumbleweed), SLES
- Arch Linux, Manjaro
- Alpine Linux

**Process**:
1. Verify distribution compatibility
2. Install `qemu-guest-agent` package (method varies by distro)
3. Enable and start the service
4. Verify service status

**Adaptive Installation**:
```bash
# Debian/Ubuntu: apt-get
# RHEL/CentOS: yum/dnf
# Fedora: dnf
# openSUSE: zypper
# Arch: pacman
# Alpine: apk
```

**Post-installation** (Proxmox configuration):
- Enable QEMU Guest Agent in VM Options (Web UI)
- Or via CLI: `qm set <VMID> --agent 1`
- Reboot VM required

---

## 🔄 Development Workflows

**IMPORTANT**: Voir `BONNES_PRATIQUES.md` pour les standards complets de développement incluant :
- Variables OS disponibles ($OS_ID, $OS_VERSION, $OS_CODENAME)
- Gestion des erreurs
- Fonctions d'affichage standardisées
- Sécurité et permissions
- Checklist complète avant commit

### Workflow 1: Adding a New Script

**Steps**:
1. Create script file: `new_script.sh`
2. Add shebang and description header:
   ```bash
   #!/bin/bash
   # Description: Your description (max 70 chars for menu display)
   ```
3. Implement script logic with error handling
4. Make executable: `chmod +x new_script.sh`
5. Test locally
6. Commit and push to GitHub
7. On server: Run `launcher.sh` → Press `U` → Script appears in menu

### Workflow 2: Modifying Existing Scripts

**Important**: Never modify `launcher.sh` directly on servers - it should be managed centrally.

**For other scripts**:
1. Clone repository locally
2. Make changes to script
3. Test in isolated environment (VM recommended)
4. Update script if it modifies system files (document in comments)
5. Commit with descriptive message
6. Push to GitHub
7. Users update via launcher `U` option

### Workflow 3: Testing Changes

**Recommended Testing Approach**:
1. **Local VM**: Use Debian 13 VM for testing
2. **Snapshot**: Take VM snapshot before running scripts
3. **Test as root**: `sudo ./script.sh`
4. **Check logs**: Review `/tmp/*_debug_*.log` and `/var/log/*_setup_*.log`
5. **Verify services**: Check systemctl status for modified services
6. **Test connectivity**: Especially for SSH changes (keep backup session open!)

---

## 📝 Code Conventions

### Shell Script Standards

**Shebang & Settings**:
```bash
#!/bin/bash
# Description: Brief description for menu display (max 70 chars)

set -e  # Exit on error (used in all scripts)
```

**Error Handling Pattern**:
```bash
# Full pattern (setup_debian_vm.sh)
trap 'handle_error ${LINENO}' ERR
trap cleanup EXIT

handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "Erreur à la ligne $line_number (code: $exit_code)"
    # Save logs and exit
}

# Simple pattern (install_docker.sh, setup_monitoring.sh)
set -e  # Just exit on error
```

**Color Definitions** (consistent across all scripts):
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color
```

**Print Functions** (standardized):
```bash
print_message() { echo -e "${BLUE}[→]${NC} $1"; }  # Info
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }  # Success
print_error() { echo -e "${RED}[✗]${NC} $1"; }      # Error
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; } # Warning
```

**Header Format**:
```bash
################################################################################
# Script Name / Purpose
# Auteur: Eloïd DOPPEL
# Description: Detailed description
################################################################################
```

**Box Drawing for Headers**:
```bash
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     Title Text                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
```

### Naming Conventions

- **Variables**: UPPER_CASE for constants/config: `SCRIPT_DIR`, `SSH_PUBLIC_KEY`
- **Functions**: snake_case: `check_root()`, `setup_github_repo()`
- **Files**: snake_case: `setup_debian_vm.sh`, `install_docker.sh`

### Script Organization Pattern

1. **Header**: Shebang, description, documentation block
2. **Settings**: `set -e`, error traps
3. **Variables**: File paths, constants, colors
4. **Functions**: Helper functions (print, check_root, etc.)
5. **Main Logic**: Numbered steps with clear comments
6. **Summary**: Final status report with next steps

### Comment Style

```bash
# Single-line comments for brief explanations

################################################################################
# Major Section Headers
################################################################################

# Detailed explanation for complex logic
# Can span multiple lines
# Each line starts with #
```

---

## ✅ Testing & Validation

### Pre-Commit Checklist

Before committing script changes:

- [ ] **Syntax**: Run `bash -n script.sh` (syntax check)
- [ ] **ShellCheck**: Run `shellcheck script.sh` (if available)
- [ ] **Permissions**: Verify `chmod +x script.sh` is applied
- [ ] **Description**: Header has `# Description:` on line 2
- [ ] **Root check**: Script includes `check_root()` if needed
- [ ] **Error handling**: Uses `set -e` or trap handlers
- [ ] **Testing**: Tested on clean Debian 13 VM

### Validation Commands

```bash
# Test syntax without execution
bash -n script.sh

# Check for common issues
shellcheck script.sh

# Test in dry-run mode (if script supports it)
DRY_RUN=1 sudo ./script.sh

# Monitor what files script modifies
sudo strace -e trace=openat,creat,unlink ./script.sh 2>&1 | grep -E "\.conf|/etc"
```

### Testing Environment Setup

**Recommended VM Configuration**:
- **OS**: Debian 13 (latest)
- **Memory**: 2GB minimum
- **Network**: NAT or Bridged (for SSH testing)
- **Snapshot**: Before each test run

**Quick VM Test Setup**:
```bash
# On test VM
git clone https://github.com/USER/debian-automation-scripts.git
cd debian-automation-scripts
chmod +x *.sh
sudo ./launcher.sh
```

---

## 🔒 Security Considerations

### Critical Security Features

**SSH Hardening** (setup_debian_vm.sh):
- ✅ Port change to 2000 (reduces automated attacks)
- ✅ Password authentication disabled
- ✅ Public key authentication only
- ✅ Root login controlled (no or prohibit-password)
- ✅ Strong ciphers: ChaCha20-Poly1305, AES-256-GCM
- ✅ Modern key exchange: Curve25519, DH group 16/18

**Firewall Configuration**:
- ✅ Default deny incoming
- ✅ Default allow outgoing
- ✅ Only SSH port 2000 allowed
- ✅ Logging enabled

**Intrusion Prevention**:
- ✅ Fail2Ban configured for SSH
- ✅ 6 failed attempts = 1 hour ban
- ✅ Monitors `/var/log/auth.log`

### Security Best Practices for Script Development

**When modifying scripts**:

1. **Never hardcode secrets**: Use prompts or environment variables
2. **Validate user input**: Check SSH keys, IP addresses, hostnames
3. **Backup before modify**: Always create backups of config files
4. **Test before apply**: Use `sshd -t` pattern for validation
5. **Log everything**: Maintain audit trail of changes
6. **Use secure defaults**: Fail closed, not open

**Dangerous Operations to Avoid**:
```bash
# ❌ NEVER DO THIS
rm -rf /var/*
chmod 777 /etc/ssh
PasswordAuthentication yes  # Without warning

# ✅ DO THIS INSTEAD
rm -rf "$SPECIFIC_TEMP_DIR"
chmod 700 /home/user/.ssh
# Show warning when enabling password auth
```

### SSH Safety Protocol

**Critical**: When modifying `setup_debian_vm.sh` SSH configuration:

1. **Always keep backup session**: Keep current SSH session open
2. **Test in new window**: Test new config in separate terminal
3. **Document rollback**: Script shows rollback command in output
4. **Automatic backup**: Script creates timestamped backups
5. **Validation step**: Uses `sshd -t` to validate before applying

Example safety message (lines 535-542):
```bash
echo "⚠ IMPORTANT - TESTEZ AVANT DE DÉCONNECTER:"
echo "  Dans un NOUVEAU terminal:"
echo "  ssh -p 2000 $USERNAME@$IP"
echo "  Si échec, restaurez depuis ce terminal:"
echo "  cp $BACKUP_FILE $SSHD_CONFIG && systemctl restart sshd"
```

---

## 🤖 Common AI Assistant Tasks

### Task 1: Add New Automation Script

**Request**: "Add a script to install Nginx with Let's Encrypt"

**Steps**:
1. Create new file: `setup_nginx_ssl.sh`
2. Add standard header:
   ```bash
   #!/bin/bash
   # Description: Installation Nginx avec Let's Encrypt SSL

   set -e
   # ... rest of standard setup
   ```
3. Implement script following conventions:
   - Use color print functions
   - Add error handling
   - Create progress indicators
   - Include validation steps
4. Make executable: `chmod +x setup_nginx_ssl.sh`
5. Test in VM
6. Commit with message: "feat: add Nginx SSL setup script"

**Files to modify**: None (just add new file)

### Task 2: Modify SSH Port

**Request**: "Change SSH port from 2000 to 2222"

**Files to modify**: `setup_debian_vm.sh`

**Changes needed**:
1. Line 331: `Port 2222` (in sshd_config template)
2. Line 402: `ufw allow 2222/tcp` (firewall rule)
3. Line 442: `port = 2222` (Fail2Ban config)
4. Lines 422, 538: Update messages mentioning port 2000

**Git workflow**:
```bash
git checkout -b feature/change-ssh-port
# Make changes
git add setup_debian_vm.sh
git commit -m "feat: change SSH port from 2000 to 2222"
git push -u origin feature/change-ssh-port
```

### Task 3: Add Support for Additional Distributions

**Request**: "Make scripts work on Ubuntu 24.04"

**Strategy**:
1. Add distribution detection:
   ```bash
   detect_distro() {
       if [ -f /etc/os-release ]; then
           . /etc/os-release
           echo "$ID"
       fi
   }
   ```
2. Conditional package names/repos:
   ```bash
   case $(detect_distro) in
       debian) RELEASE=$(lsb_release -cs) ;;
       ubuntu) RELEASE=$(lsb_release -cs) ;;
   esac
   ```
3. Test on both distributions
4. Update README.md to document Ubuntu support

**Files to modify**: All `.sh` scripts + README.md

### Task 4: Improve Error Messages

**Request**: "Make error messages more helpful with troubleshooting steps"

**Pattern to implement**:
```bash
print_error_with_fix() {
    local error_msg=$1
    local fix_cmd=$2
    print_error "$error_msg"
    echo -e "${YELLOW}[→]${NC} Pour corriger: $fix_cmd"
}

# Usage
print_error_with_fix \
    "Échec connexion au serveur Zabbix" \
    "Vérifiez: ping $ZABBIX_SERVER"
```

**Files to modify**: All scripts with error handling

### Task 5: Add Logging Enhancements

**Request**: "Add structured JSON logging for monitoring"

**Implementation**:
```bash
LOG_JSON="/var/log/debian_setup_$(date +%Y%m%d_%H%M%S).json"

log_event() {
    local level=$1
    local message=$2
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}" >> "$LOG_JSON"
}

# Usage
log_event "INFO" "Starting SSH configuration"
log_event "ERROR" "Failed to restart SSH service"
```

**Files to modify**: `setup_debian_vm.sh` primarily (most complex script)

### Task 6: Internationalization

**Request**: "Add English language support"

**Strategy**:
```bash
# Detect language from environment or prompt
LANG_CHOICE=${LANG_OVERRIDE:-"fr"}

msg() {
    local key=$1
    case "$key" in
        "start_update")
            [[ "$LANG_CHOICE" == "en" ]] && echo "Updating system" || echo "Mise à jour du système"
            ;;
        "success_update")
            [[ "$LANG_CHOICE" == "en" ]] && echo "System updated" || echo "Système mis à jour"
            ;;
    esac
}

# Usage
print_message "$(msg start_update)"
```

**Files to modify**: All scripts + add `i18n/` directory with message files

---

## 🐛 Troubleshooting Guide

### Common Issues

#### Issue 1: Launcher Not Finding Scripts

**Symptoms**: Menu shows only option #1 (setup_debian_vm.sh)

**Causes**:
- GitHub repo not configured
- Scripts not executable in cloned repo
- Missing `# Description:` header

**Fix**:
```bash
# Check config
cat /root/.launcher_config

# If no GITHUB_REPO, configure it
sudo ./launcher.sh → Press G

# Fix permissions in cloned repo
chmod +x /root/scripts/*.sh

# Verify Description headers
head -n 2 /root/scripts/*.sh
```

#### Issue 2: SSH Lockout After setup_debian_vm.sh

**Symptoms**: Cannot connect via SSH after running script

**Causes**:
- SSH key not properly configured
- Firewall blocking port 2000
- SSH service failed to restart

**Prevention**:
- Always test in NEW terminal before closing original session
- Keep backup session open during testing

**Recovery** (from console/KVM):
```bash
# Restore SSH config
cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
systemctl restart sshd

# Check firewall
ufw status
ufw allow 22/tcp  # Temporarily allow default port

# Check SSH service
systemctl status sshd
journalctl -u sshd -n 50
```

#### Issue 3: Git Pull Fails in Launcher

**Symptoms**: Press `U` → "Échec de la mise à jour"

**Causes**:
- Network connectivity issues
- Authentication problems (private repos)
- Local changes in scripts directory

**Fix**:
```bash
cd /root/scripts
git status  # Check for local changes
git reset --hard origin/main  # Discard local changes
git pull origin main
```

#### Issue 4: Docker Installation Fails

**Symptoms**: install_docker.sh fails during apt install

**Causes**:
- Incompatible Debian version
- Network issues downloading from Docker repo
- Conflicting packages

**Fix**:
```bash
# Check Debian version
lsb_release -a

# Verify network connectivity
curl -I https://download.docker.com

# Remove conflicting packages
apt remove docker docker-engine docker.io containerd runc

# Try again
sudo ./install_docker.sh
```

#### Issue 5: Fail2Ban Not Starting

**Symptoms**: setup_debian_vm.sh completes but Fail2Ban not active

**Causes**:
- Invalid jail.local syntax
- Conflicting configuration files
- Missing log file

**Fix**:
```bash
# Check status
systemctl status fail2ban

# View detailed errors
journalctl -xe -u fail2ban

# Test configuration
fail2ban-client -t

# Restart with verbose logging
fail2ban-client -v start
```

---

## 📚 Additional Resources

### Related Documentation
- `README.md`: User-facing documentation (French)
- `SETUP_GUIDE.md`: GitHub repository setup instructions
- `INSTRUCTIONS.md`: Quick deployment guide
- `BONNES_PRATIQUES.md`: **Best practices for script development** (Variables OS, standards, checklist)

### External References
- [Debian Security Manual](https://www.debian.org/doc/manuals/securing-debian-manual/)
- [OpenSSH Hardening Guide](https://infosec.mozilla.org/guidelines/openssh)
- [Fail2Ban Documentation](https://www.fail2ban.org/)
- [Docker on Debian](https://docs.docker.com/engine/install/debian/)

### System Requirements
- **OS**: Debian 13 (Trixie) - primary target
- **Privileges**: Root/sudo access required
- **Network**: Internet connectivity for package downloads
- **Dependencies**: Auto-installed (git, whiptail)

---

## 🔄 Version History & Updates

### Current Status (as of this document)
- **Branch**: `claude/claude-md-mhy7gvmsan182189-01Dy337BNbetAVZG1Qd3DnVY`
- **Recent Commits**:
  - `5cae075`: Add files via upload
  - `7c7f1a4`: Initial commit

### When Updating This Document
- **Add new scripts**: Document in "Scripts Deep Dive" section
- **Change conventions**: Update "Code Conventions" section
- **Add workflows**: Document in "Development Workflows" section
- **Security changes**: Update "Security Considerations" section

---

## 🎓 Learning Path for New Contributors

### Phase 1: Understanding (Week 1)
1. Read README.md and SETUP_GUIDE.md
2. Run launcher.sh in test VM to see user experience
3. Read through all scripts to understand patterns
4. Test each script individually in isolated VM

### Phase 2: Contributing (Week 2-3)
1. Fix small bugs or improve error messages
2. Add minor features (logging enhancements, better prompts)
3. Write new scripts following conventions
4. Practice git workflow with feature branches

### Phase 3: Advanced (Week 4+)
1. Refactor complex functions
2. Add new major features
3. Improve launcher functionality
4. Mentor other contributors

---

## 📞 Support & Contact

**Repository Owner**: ResTozz
**Author**: Eloïd DOPPEL - Administrateur Système et Réseaux
**Organization**: DoppelServices
**Infrastructure Context**: Multi-site (UniFi SD-WAN), BTS CIEL training

**For Issues**: Use GitHub Issues on repository
**For Security Issues**: Contact repository owner directly (do not open public issues)

---

## ✨ Final Notes for AI Assistants

### Do's ✅
- Follow established code conventions strictly
- Test all changes in VM before committing
- Maintain French language in user-facing messages
- Prioritize security in all modifications
- Document changes clearly in commit messages
- Use color-coded output for better UX
- Handle errors gracefully with helpful messages

### Don'ts ❌
- Don't modify security settings without understanding impact
- Don't remove error handling or logging
- Don't change language to English without request
- Don't commit untested code
- Don't hardcode secrets or credentials
- Don't skip the description header in new scripts
- Don't break backward compatibility with launcher

### When In Doubt
1. **Read existing code**: Find similar pattern in codebase
2. **Test thoroughly**: Use VM for all system-level changes
3. **Ask for clarification**: Better to confirm than assume
4. **Document decisions**: Comment complex logic
5. **Follow security first**: When unsure, choose more secure option

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Maintained By**: AI Assistant (Claude)
