#!/bin/bash

# Script d'audit complet Synology NAS
# Usage: ./synology_audit.sh [fonction] ou ./synology_audit.sh pour menu interactif
# Auteur: Script d'audit générique pour NAS Synology

set -e

# Configuration globale
SCRIPT_VERSION="1.0"
AUDIT_DIR="/tmp/synology_audit_$(date +%Y%m%d_%H%M%S)"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOGFILE="$AUDIT_DIR/audit.log"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Fonctions utilitaires
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOGFILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOGFILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGFILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGFILE"
}

section() {
    echo -e "${CYAN}${BOLD}=== $1 ===${NC}" | tee -a "$LOGFILE"
}

# Fonction pour vérifier et exécuter une commande avec alternative
safe_command() {
    local cmd="$1"
    local alternative="$2"
    local description="$3"
    
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        if [ -n "$alternative" ]; then
            echo "Commande '$cmd' non disponible - $description"
            eval "$alternative"
        else
            echo "Commande '$cmd' non disponible sur ce système"
        fi
        return 1
    fi
}

# Initialisation de l'audit
init_audit() {
    mkdir -p "$AUDIT_DIR"
    section "AUDIT SYNOLOGY NAS - VERSION $SCRIPT_VERSION"
    log "Hostname: $HOSTNAME"
    log "Date: $DATE"
    log "Répertoire audit: $AUDIT_DIR"
    
    # Vérification des commandes optionnelles
    local missing_commands=()
    local optional_commands=("smartctl" "docker" "systemctl" "iptables" "synouser" "lsblk")
    
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        warning "Commandes optionnelles non disponibles: ${missing_commands[*]}"
        info "L'audit continuera avec les alternatives disponibles"
    fi
    
    echo ""
}

# Fonction 1: Audit système et matériel
audit_system() {
    local output="$AUDIT_DIR/01_system_hardware.txt"
    section "Audit système et matériel"
    
    {
        echo "=== INFORMATIONS SYSTÈME ==="
        echo "Date audit: $DATE"
        echo "Hostname: $HOSTNAME"
        echo "Script version: $SCRIPT_VERSION"
        echo ""
        
        echo "=== VERSION DSM ==="
        if [ -f /etc/VERSION ]; then
            cat /etc/VERSION
        fi
        if [ -f /etc.defaults/VERSION ]; then
            echo ""
            echo "Version par défaut:"
            cat /etc.defaults/VERSION
        fi
        echo ""
        
        echo "=== INFORMATIONS MATÉRIEL ==="
        echo "Architecture: $(uname -m)"
        echo "Kernel: $(uname -r)"
        echo "Système: $(uname -s)"
        echo "Uptime: $(uptime)"
        echo ""
        
        echo "=== PROCESSEUR ==="
        if [ -f /proc/cpuinfo ]; then
            grep -E "(model name|cpu cores|siblings|processor)" /proc/cpuinfo | head -10
        fi
        echo ""
        
        echo "=== MÉMOIRE ==="
        free -h 2>/dev/null || free
        echo ""
        if [ -f /proc/meminfo ]; then
            grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal)" /proc/meminfo
        fi
        echo ""
        
        echo "=== STOCKAGE - VUE GÉNÉRALE ==="
        df -h 2>/dev/null
        echo ""
        
        echo "=== PÉRIPHÉRIQUES BLOC ==="
        lsblk 2>/dev/null || echo "lsblk non disponible"
        echo ""
        
        echo "=== INTERFACES RÉSEAU ==="
        ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "Interfaces non accessibles"
        echo ""
        
        echo "=== PROCESSUS SYSTÈME PRINCIPAUX ==="
        ps aux | head -1
        ps aux | grep -E "(dsm|syno)" | head -15
        
    } > "$output"
    
    info "Système sauvegardé: $(basename "$output")"
}

# Fonction 2: Audit utilisateurs et groupes
audit_users() {
    local output="$AUDIT_DIR/02_users_groups.txt"
    section "Audit utilisateurs et groupes"
    
    {
        echo "=== AUDIT UTILISATEURS ET GROUPES ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== UTILISATEURS DSM ==="
        if command -v synouser &> /dev/null; then
            echo "Utilisateurs DSM (via synouser):"
            synouser --enum all 2>/dev/null || echo "Erreur lors de l'énumération des utilisateurs DSM"
        else
            echo "Commande synouser non disponible, utilisation de /etc/passwd:"
            if [ -f /etc/passwd ]; then
                echo "Utilisateurs avec UID >= 1000 ou admin:"
                while IFS=: read -r username password uid gid gecos home shell; do
                    if [ "$uid" -ge 1000 ] || [ "$username" = "admin" ] || [ "$username" = "guest" ]; then
                        echo "  - $username (UID: $uid, GID: $gid, Home: $home, Shell: $shell)"
                    fi
                done < /etc/passwd
            fi
        fi
        echo ""
        
        echo "=== GROUPES SYSTÈME ==="
        if [ -f /etc/group ]; then
            echo "Groupes principaux:"
            grep -E "(admin|users|guests|wheel|sudo)" /etc/group || echo "Groupes standards non trouvés"
            echo ""
            echo "Tous les groupes (premiers 20):"
            head -20 /etc/group
        fi
        echo ""
        
        echo "=== DOSSIERS UTILISATEURS ==="
        if [ -d /volume1/homes ]; then
            echo "Contenu /volume1/homes:"
            ls -la /volume1/homes/ 2>/dev/null || echo "Accès refusé à /volume1/homes"
        else
            echo "Répertoire /volume1/homes non trouvé"
        fi
        echo ""
        
        echo "=== SESSIONS ACTIVES ==="
        who 2>/dev/null || echo "Commande who non disponible"
        echo ""
        
        echo "=== HISTORIQUE CONNEXIONS ==="
        last | head -15 2>/dev/null || echo "Historique non accessible"
        echo ""
        
        echo "=== PERMISSIONS VOLUME PRINCIPAL ==="
        if [ -d /volume1 ]; then
            echo "Permissions /volume1:"
            ls -la /volume1/ 2>/dev/null | head -20
        fi
        
    } > "$output"
    
    info "Utilisateurs sauvegardés: $(basename "$output")"
}

# Fonction 3: Audit services réseau
audit_services() {
    local output="$AUDIT_DIR/03_network_services.txt"
    section "Audit services réseau"
    
    {
        echo "=== SERVICES RÉSEAU ET PROCESSUS ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== PORTS OUVERTS ==="
        echo "Port      Protocol  Service        Process"
        echo "-------   --------  -----------    ---------"
        if command -v netstat &> /dev/null; then
            netstat -tulpn 2>/dev/null | grep LISTEN | while read line; do
                # Extraction du port sans utiliser rev
                port=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
                protocol=$(echo "$line" | awk '{print $1}')
                process=$(echo "$line" | awk '{print $7}' | cut -d/ -f2 2>/dev/null || echo "unknown")
                
                case "$port" in
                    22) service="SSH" ;;
                    80) service="HTTP" ;;
                    443) service="HTTPS" ;;
                    139|445) service="SMB/CIFS" ;;
                    21) service="FTP" ;;
                    2049) service="NFS" ;;
                    5000|5001) service="DSM Web" ;;
                    *) service="Other" ;;
                esac
                
                printf "%-8s  %-8s  %-11s    %s\n" "$port" "$protocol" "$service" "$process"
            done
        else
            ss -tulpn 2>/dev/null | grep LISTEN || echo "Impossible d'obtenir la liste des ports"
        fi
        echo ""
        
        echo "=== SERVICE SSH ==="
        echo "Processus SSH:"
        ps aux | grep sshd | grep -v grep
        echo ""
        if [ -f /etc/ssh/sshd_config ]; then
            echo "Configuration SSH principale:"
            grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config || echo "Configuration par défaut"
        fi
        echo ""
        
        echo "=== SERVICES SMB/CIFS ==="
        echo "Processus Samba:"
        ps aux | grep -E "(smbd|nmbd)" | grep -v grep || echo "Processus Samba non trouvés"
        echo ""
        if [ -f /etc/samba/smb.conf ]; then
            echo "Configuration Samba (sections principales):"
            grep -E "^\[|^[[:space:]]*(workgroup|server string|security)" /etc/samba/smb.conf | head -15
        fi
        echo ""
        
        echo "=== SERVICES FTP ==="
        ps aux | grep -i ftp | grep -v grep || echo "Pas de service FTP actif"
        echo ""
        
        echo "=== SERVICES NFS ==="
        ps aux | grep nfs | grep -v grep || echo "Pas de service NFS actif"
        echo ""
        if [ -f /etc/exports ]; then
            echo "Exports NFS configurés:"
            cat /etc/exports
        fi
        echo ""
        
        echo "=== SERVICES WEB ==="
        ps aux | grep -E "(httpd|nginx|apache|lighttpd)" | grep -v grep || echo "Pas de serveur web détecté"
        echo ""
        
        echo "=== SERVICES SYNOLOGY SPÉCIFIQUES ==="
        echo "Processus Synology actifs:"
        ps aux | grep syno | grep -v grep | awk '{print $11}' | sort | uniq -c | head -15
        
    } > "$output"
    
    info "Services sauvegardés: $(basename "$output")"
}

# Fonction 4: Audit partages et dossiers partagés
audit_shares() {
    local output="$AUDIT_DIR/04_shares_folders.txt"
    section "Audit partages et dossiers"
    
    {
        echo "=== PARTAGES ET DOSSIERS PARTAGÉS ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== STRUCTURE VOLUMES ==="
        echo "Volumes montés:"
        df -h | grep -E "(volume|md)" || echo "Pas de volumes spécifiques détectés"
        echo ""
        
        echo "=== CONTENU VOLUME1 ==="
        if [ -d /volume1 ]; then
            echo "Dossiers de premier niveau dans /volume1:"
            find /volume1 -maxdepth 1 -type d | sort
            echo ""
            
            echo "Taille des dossiers principaux:"
            for dir in /volume1/*/; do
                if [ -d "$dir" ]; then
                    size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "N/A")
                    echo "  $(basename "$dir"): $size"
                fi
            done | sort -hr
            echo ""
        else
            echo "/volume1 non trouvé"
        fi
        
        echo "=== CONFIGURATION PARTAGES SMB ==="
        if [ -f /etc/samba/smb.conf ]; then
            echo "Partages SMB configurés:"
            grep "^\[" /etc/samba/smb.conf | grep -v "global" | while read section; do
                share_name=$(echo "$section" | tr -d '[]')
                echo ""
                echo "📁 PARTAGE: $share_name"
                
                # Extraire la configuration de ce partage
                awk "/^\[$share_name\]/,/^\[/{print}" /etc/samba/smb.conf | grep -E "path|comment|valid users|read only|browseable|writable" | while read line; do
                    echo "    $line"
                done
                
                # Vérifier l'existence du chemin
                path=$(awk "/^\[$share_name\]/,/^\[/{print}" /etc/samba/smb.conf | grep "path" | cut -d= -f2 | tr -d ' ' | head -1)
                if [ -n "$path" ] && [ -d "$path" ]; then
                    size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "N/A")
                    files=$(find "$path" -type f 2>/dev/null | wc -l || echo "N/A")
                    perms=$(ls -ld "$path" 2>/dev/null | awk '{print $1 " " $3 ":" $4}' || echo "N/A")
                    echo "    Taille: $size"
                    echo "    Fichiers: $files"
                    echo "    Permissions: $perms"
                elif [ -n "$path" ]; then
                    echo "    ⚠️  Chemin non accessible: $path"
                fi
            done
        else
            echo "Fichier smb.conf non trouvé"
        fi
        echo ""
        
        echo "=== PARTAGES NFS ==="
        if [ -f /etc/exports ]; then
            echo "Exports NFS configurés:"
            cat /etc/exports
        else
            echo "Pas d'exports NFS configurés"
        fi
        echo ""
        
        echo "=== PERMISSIONS DÉTAILLÉES DOSSIERS PRINCIPAUX ==="
        if [ -d /volume1 ]; then
            for dir in /volume1/*/; do
                if [ -d "$dir" ]; then
                    dirname=$(basename "$dir")
                    echo ""
                    echo "=== $dirname ==="
                    ls -ld "$dir" 2>/dev/null || echo "Accès refusé"
                    echo "Contenu (5 premiers éléments):"
                    ls -la "$dir" 2>/dev/null | head -6 || echo "Accès refusé"
                fi
            done
        fi
        
    } > "$output"
    
    info "Partages sauvegardés: $(basename "$output")"
}

# Fonction 5: Audit configuration réseau
audit_network() {
    local output="$AUDIT_DIR/05_network_config.txt"
    section "Audit configuration réseau"
    
    {
        echo "=== CONFIGURATION RÉSEAU COMPLÈTE ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== INTERFACES RÉSEAU ==="
        if command -v ip &> /dev/null; then
            ip addr show
        else
            ifconfig 2>/dev/null || echo "Impossible d'obtenir les interfaces"
        fi
        echo ""
        
        echo "=== TABLE DE ROUTAGE ==="
        if command -v ip &> /dev/null; then
            ip route show
        else
            route -n 2>/dev/null || echo "Table de routage non accessible"
        fi
        echo ""
        
        echo "=== CONFIGURATION DNS ==="
        if [ -f /etc/resolv.conf ]; then
            echo "Contenu /etc/resolv.conf:"
            cat /etc/resolv.conf
        fi
        echo ""
        
        echo "=== HOSTNAME ET DOMAINE ==="
        echo "Hostname: $(hostname)"
        echo "FQDN: $(hostname -f 2>/dev/null || echo "Non disponible")"
        if [ -f /etc/hostname ]; then
            echo "Fichier hostname: $(cat /etc/hostname)"
        fi
        echo ""
        
        echo "=== CONFIGURATION DHCP ==="
        if [ -f /etc/dhcpcd.conf ]; then
            echo "Configuration DHCP:"
            grep -v "^#" /etc/dhcpcd.conf | grep -v "^$" || echo "Configuration par défaut"
        fi
        echo ""
        
        echo "=== RÈGLES FIREWALL ==="
        iptables -L -n 2>/dev/null || echo "iptables non accessible"
        echo ""
        
        echo "=== TEST CONNECTIVITÉ ==="
        echo "Test ping vers 8.8.8.8:"
        ping -c 3 8.8.8.8 2>/dev/null || echo "Ping échoué"
        echo ""
        echo "Test résolution DNS:"
        nslookup google.com 2>/dev/null || echo "Résolution DNS échouée"
        
    } > "$output"
    
    info "Réseau sauvegardé: $(basename "$output")"
}

# Fonction 6: Audit stockage et RAID
audit_storage() {
    local output="$AUDIT_DIR/06_storage_raid.txt"
    section "Audit stockage et RAID"
    
    {
        echo "=== STOCKAGE ET CONFIGURATION RAID ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== DISQUES PHYSIQUES ==="
        if command -v lsblk &> /dev/null; then
            lsblk
        else
            echo "lsblk non disponible - utilisation d'alternatives:"
            echo ""
            echo "Périphériques de stockage détectés:"
            ls -la /dev/sd[a-z] 2>/dev/null || echo "Aucun disque SATA détecté"
            echo ""
            echo "Partitions montées:"
            mount | grep -E "(sd|volume)" || echo "Aucune partition de stockage détectée"
        fi
        echo ""
        
        echo "=== PARTITIONS ==="
        fdisk -l 2>/dev/null | grep -E "(Disk|Device|Type)" || echo "fdisk non accessible"
        echo ""
        
        echo "=== VOLUMES ET MONTAGES ==="
        df -h
        echo ""
        
        echo "=== INFORMATION RAID ==="
        if [ -f /proc/mdstat ]; then
            echo "Status RAID (mdstat):"
            cat /proc/mdstat
        else
            echo "Pas d'information RAID md disponible"
        fi
        echo ""
        
        echo "=== MONTAGES ACTIFS ==="
        mount | grep -E "(volume|md|ext|btrfs)" || mount
        echo ""
        
        echo "=== FSTAB ==="
        if [ -f /etc/fstab ]; then
            cat /etc/fstab
        else
            echo "fstab non trouvé"
        fi
        echo ""
        
        echo "=== UTILISATION DÉTAILLÉE VOLUME1 ==="
        if [ -d /volume1 ]; then
            echo "Statistiques volume1:"
            df -h /volume1
            echo ""
            echo "Utilisation par dossier (top 15):"
            du -sh /volume1/* 2>/dev/null | sort -hr | head -15
            echo ""
            echo "Informations inodes:"
            df -i /volume1 2>/dev/null || echo "Informations inodes non disponibles"
        fi
        echo ""
        
        echo "=== SANTÉ DES DISQUES (SMART) ==="
        if command -v smartctl &> /dev/null; then
            for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
                if [ -b "$disk" ]; then
                    echo ""
                    echo "=== SMART $disk ==="
                    smartctl -i "$disk" 2>/dev/null | grep -E "(Model|Serial|Firmware)" || echo "Informations de base non disponibles"
                    smartctl -H "$disk" 2>/dev/null || echo "Test de santé non disponible"
                    smartctl -a "$disk" 2>/dev/null | grep -E "(Temperature|Power_On_Hours|Reallocated_Sector|Current_Pending_Sector)" || echo "Attributs SMART non disponibles"
                fi
            done
        else
            echo "smartctl non disponible - utilisation d'alternatives basiques"
            echo ""
            echo "Disques détectés:"
            ls -la /dev/sd[a-z] 2>/dev/null || echo "Aucun disque SATA détecté"
            echo ""
            echo "Informations basiques disques:"
            if [ -f /proc/diskstats ]; then
                echo "Statistiques disques (depuis /proc/diskstats):"
                grep -E "(sd[a-z]|nvme)" /proc/diskstats | head -10
            fi
        fi
        
    } > "$output"
    
    info "Stockage sauvegardé: $(basename "$output")"
}

# Fonction 7: Audit applications et packages
audit_applications() {
    local output="$AUDIT_DIR/07_applications_packages.txt"
    section "Audit applications et packages"
    
    {
        echo "=== APPLICATIONS ET PACKAGES INSTALLÉS ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== PACKAGES SYNOLOGY ==="
        if [ -d /var/packages ]; then
            echo "Packages installés dans /var/packages:"
            ls -la /var/packages/ 2>/dev/null
            echo ""
            
            echo "Détails des packages:"
            for pkg_dir in /var/packages/*/; do
                if [ -d "$pkg_dir" ]; then
                    pkg_name=$(basename "$pkg_dir")
                    echo ""
                    echo "📦 PACKAGE: $pkg_name"
                    
                    if [ -f "$pkg_dir/INFO" ]; then
                        echo "  Informations:"
                        grep -E "(version|displayname|description|maintainer)" "$pkg_dir/INFO" 2>/dev/null | sed 's/^/    /'
                    fi
                    
                    if [ -f "$pkg_dir/conf/privilege" ]; then
                        echo "  Privilèges requis:"
                        cat "$pkg_dir/conf/privilege" 2>/dev/null | sed 's/^/    /'
                    fi
                fi
            done
        else
            echo "Répertoire /var/packages non trouvé"
        fi
        echo ""
        
        echo "=== SERVICES DOCKER ==="
        if command -v docker &> /dev/null; then
            echo "Conteneurs Docker:"
            docker ps -a 2>/dev/null || echo "Impossible d'accéder à Docker"
            echo ""
            echo "Images Docker:"
            docker images 2>/dev/null || echo "Impossible de lister les images"
        else
            echo "Docker non installé ou non accessible"
        fi
        echo ""
        
        echo "=== PROCESSUS APPLICATIONS ==="
        echo "Processus d'applications courantes:"
        ps aux | grep -E "(plex|git|node|python|php|java|apache|nginx)" | grep -v grep || echo "Aucun processus d'application standard détecté"
        echo ""
        
        echo "=== PORTS APPLICATIONS ==="
        echo "Ports d'applications courantes ouverts:"
        if command -v netstat &> /dev/null; then
            netstat -tulpn 2>/dev/null | grep LISTEN | while read line; do
                port=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
                case "$port" in
                    8080|9000|32400|5000|8096|3000|8000|8443)
                        process=$(echo "$line" | awk '{print $7}' | cut -d/ -f2 || echo "unknown")
                        echo "  Port $port ($process)"
                        ;;
                esac
            done || echo "Aucun port d'application standard ouvert"
        else
            echo "netstat non disponible"
        fi
        echo ""
        
        echo "=== SERVICES SYSTÈME ACTIFS ==="
        if command -v systemctl &> /dev/null; then
            systemctl list-units --type=service --state=active 2>/dev/null | head -20 || echo "systemctl non accessible"
        else
            echo "systemctl non disponible"
        fi
        
    } > "$output"
    
    info "Applications sauvegardées: $(basename "$output")"
}

# Fonction 8: Audit tâches planifiées
audit_scheduled_tasks() {
    local output="$AUDIT_DIR/08_scheduled_tasks.txt"
    section "Audit tâches planifiées"
    
    {
        echo "=== TÂCHES PLANIFIÉES ET AUTOMATION ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== CRONTAB ROOT ==="
        crontab -l 2>/dev/null || echo "Pas de crontab pour root"
        echo ""
        
        echo "=== CRONTAB SYSTÈME ==="
        if [ -d /etc/cron.d ]; then
            echo "Fichiers dans /etc/cron.d:"
            ls -la /etc/cron.d/ 2>/dev/null
            echo ""
            
            for cronfile in /etc/cron.d/*; do
                if [ -f "$cronfile" ]; then
                    echo "=== Contenu $(basename "$cronfile") ==="
                    cat "$cronfile" 2>/dev/null
                    echo ""
                fi
            done
        else
            echo "Répertoire /etc/cron.d non trouvé"
        fi
        
        echo "=== CRON SYSTÈME STANDARD ==="
        for crondir in hourly daily weekly monthly; do
            if [ -d "/etc/cron.$crondir" ]; then
                echo "Scripts cron.$crondir:"
                ls -la "/etc/cron.$crondir/" 2>/dev/null
                echo ""
            fi
        done
        
        echo "=== TÂCHES SYNOLOGY SPÉCIFIQUES ==="
        if [ -d /usr/syno/etc/crontab ]; then
            echo "Crontab Synology:"
            ls -la /usr/syno/etc/crontab/ 2>/dev/null
            echo ""
        fi
        
        echo "=== SCRIPTS PERSONNALISÉS ==="
        echo "Scripts shell dans /volume1 (20 premiers):"
        find /volume1 -name "*.sh" -type f 2>/dev/null | head -20 || echo "Aucun script trouvé dans /volume1"
        echo ""
        
        echo "Scripts dans /usr/local/bin:"
        ls -la /usr/local/bin/ 2>/dev/null | grep ".sh" || echo "Aucun script dans /usr/local/bin"
        
    } > "$output"
    
    info "Tâches sauvegardées: $(basename "$output")"
}

# Fonction 9: Audit sécurité
audit_security() {
    local output="$AUDIT_DIR/09_security_config.txt"
    section "Audit configuration sécurité"
    
    {
        echo "=== CONFIGURATION SÉCURITÉ ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== UTILISATEURS PRIVILÉGIÉS ==="
        echo "Utilisateurs dans le groupe admin:"
        grep "admin" /etc/group 2>/dev/null | cut -d: -f4
        echo ""
        
        echo "Utilisateurs avec sudo/wheel:"
        grep -E "(sudo|wheel)" /etc/group 2>/dev/null || echo "Groupes sudo/wheel non trouvés"
        echo ""
        
        echo "=== LOGS DE SÉCURITÉ ==="
        echo "Tentatives de connexion SSH récentes:"
        if [ -f /var/log/auth.log ]; then
            grep "sshd" /var/log/auth.log 2>/dev/null | tail -10 || echo "Pas d'entrées SSH récentes"
        else
            echo "Log auth.log non trouvé"
        fi
        echo ""
        
        echo "Échecs d'authentification:"
        if [ -f /var/log/auth.log ]; then
            grep -i "failed\|failure" /var/log/auth.log 2>/dev/null | tail -10 || echo "Pas d'échecs récents"
        else
            echo "Logs non accessibles"
        fi
        echo ""
        
        echo "=== CERTIFICATS SSL ==="
        echo "Certificats Synology:"
        find /usr/syno/etc/certificate -name "*.crt" 2>/dev/null | head -10 || echo "Certificats non trouvés"
        echo ""
        
        echo "=== CONFIGURATION FIREWALL ==="
        echo "Règles iptables INPUT:"
        iptables -L INPUT -n 2>/dev/null || echo "iptables non accessible"
        echo ""
        
        echo "=== SERVICES D'ÉCOUTE ==="
        echo "Services exposés sur toutes les interfaces:"
        netstat -tulpn 2>/dev/null | grep "0.0.0.0" | head -10 || echo "Informations non disponibles"
        echo ""
        
        echo "=== PERMISSIONS CRITIQUES ==="
        echo "Fichiers SUID/SGID (10 premiers):"
        find /usr -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -10 || echo "Recherche échouée"
        
    } > "$output"
    
    info "Sécurité sauvegardée: $(basename "$output")"
}

# Fonction 10: Génération du rapport de synthèse
generate_summary_report() {
    local report="$AUDIT_DIR/00_RAPPORT_SYNTHESE.md"
    section "Génération du rapport de synthèse"
    
    {
        echo "# Rapport d'audit Synology NAS"
        echo ""
        echo "**Date d'audit:** $DATE"
        echo "**Hostname:** $HOSTNAME"
        echo "**Version script:** $SCRIPT_VERSION"
        echo "**Répertoire audit:** $AUDIT_DIR"
        echo ""
        
        echo "## 📋 Résumé exécutif"
        echo ""
        
        echo "### 🖥️ Système"
        if [ -f "$AUDIT_DIR/01_system_hardware.txt" ]; then
            dsm_version=$(grep -A3 "VERSION DSM" "$AUDIT_DIR/01_system_hardware.txt" | grep -E "(version|productversion)" | head -1 | cut -d= -f2 2>/dev/null || echo "Non déterminé")
            architecture=$(grep "Architecture:" "$AUDIT_DIR/01_system_hardware.txt" | cut -d: -f2 | tr -d ' ' 2>/dev/null || echo "Non déterminé")
            memory=$(grep "MemTotal" "$AUDIT_DIR/01_system_hardware.txt" | awk '{print $2 " " $3}' 2>/dev/null || echo "Non déterminé")
            
            echo "- **Version DSM:** $dsm_version"
            echo "- **Architecture:** $architecture"
            echo "- **Mémoire totale:** $memory"
        fi
        echo ""
        
        echo "### 💾 Stockage"
        if [ -f "$AUDIT_DIR/06_storage_raid.txt" ]; then
            if [ -d /volume1 ]; then
                volume_usage=$(df -h /volume1 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}' 2>/dev/null || echo "Non déterminé")
                echo "- **Volume principal:** /volume1"
                echo "- **Utilisation:** $volume_usage"
            fi
            
            folder_count=$(ls -1 /volume1/ 2>/dev/null | wc -l || echo "0")
            echo "- **Dossiers principaux:** $folder_count dossiers"
        fi
        echo ""
        
        echo "### 📁 Partages"
        if [ -f "$AUDIT_DIR/04_shares_folders.txt" ]; then
            smb_shares=$(grep "^\[" /etc/samba/smb.conf 2>/dev/null | grep -v global | wc -l || echo "0")
            echo "- **Partages SMB configurés:** $smb_shares"
            
            if [ -f /etc/exports ]; then
                nfs_exports=$(wc -l < /etc/exports 2>/dev/null || echo "0")
                echo "- **Exports NFS:** $nfs_exports"
            fi
        fi
        echo ""
        
        echo "### 🌐 Réseau et services"
        if [ -f "$AUDIT_DIR/03_network_services.txt" ]; then
            open_ports=$(netstat -tulpn 2>/dev/null | grep LISTEN | wc -l || echo "0")
            echo "- **Ports ouverts:** $open_ports"
            
            if pgrep sshd > /dev/null; then
                echo "- **SSH:** ✅ Actif"
            else
                echo "- **SSH:** ❌ Inactif"
            fi
            
            if pgrep smbd > /dev/null; then
                echo "- **SMB/CIFS:** ✅ Actif"
            else
                echo "- **SMB/CIFS:** ❌ Inactif"
            fi
        fi
        echo ""
        
        echo "### 👥 Utilisateurs"
        if [ -f "$AUDIT_DIR/02_users_groups.txt" ]; then
            if [ -d /volume1/homes ]; then
                user_count=$(ls -1 /volume1/homes/ 2>/dev/null | wc -l || echo "0")
                echo "- **Comptes utilisateurs:** $user_count (avec dossiers home)"
            fi
        fi
        echo ""
        
        echo "### 📦 Applications"
        if [ -f "$AUDIT_DIR/07_applications_packages.txt" ]; then
            if [ -d /var/packages ]; then
                package_count=$(ls -1 /var/packages/ 2>/dev/null | wc -l || echo "0")
                echo "- **Packages installés:** $package_count"
            fi
        fi
        echo ""
        
        echo "## 📄 Fichiers d'audit générés"
        echo ""
        for file in "$AUDIT_DIR"/*.txt; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                size=$(ls -lh "$file" | awk '{print $5}')
                description=""
                case "$filename" in
                    "01_system_hardware.txt") description="Informations système et matériel" ;;
                    "02_users_groups.txt") description="Utilisateurs et groupes" ;;
                    "03_network_services.txt") description="Services réseau et processus" ;;
                    "04_shares_folders.txt") description="Partages et dossiers partagés" ;;
                    "05_network_config.txt") description="Configuration réseau complète" ;;
                    "06_storage_raid.txt") description="Stockage et configuration RAID" ;;
                    "07_applications_packages.txt") description="Applications et packages" ;;
                    "08_scheduled_tasks.txt") description="Tâches planifiées" ;;
                    "09_security_config.txt") description="Configuration sécurité" ;;
                esac
                echo "- **$filename** ($size) - $description"
            fi
        done
        echo ""
        
        echo "## ⚠️ Points d'attention"
        echo ""
        
        # Vérifications automatiques
        if [ -f "$AUDIT_DIR/06_storage_raid.txt" ]; then
            volume_usage_percent=$(df /volume1 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' 2>/dev/null || echo "0")
            if [ "$volume_usage_percent" -gt 90 ]; then
                echo "- 🔴 **Espace disque critique:** Volume1 utilisé à ${volume_usage_percent}%"
            elif [ "$volume_usage_percent" -gt 80 ]; then
                echo "- 🟡 **Espace disque:** Volume1 utilisé à ${volume_usage_percent}%"
            fi
        fi
        
        if [ -f "$AUDIT_DIR/09_security_config.txt" ]; then
            ssh_port=$(netstat -tulpn 2>/dev/null | grep ":22 " | wc -l || echo "0")
            if [ "$ssh_port" -gt 0 ]; then
                echo "- 🟡 **SSH exposé:** Service SSH accessible (port 22)"
            fi
        fi
        
        echo ""
        echo "## 📝 Recommandations pour migration/sauvegarde"
        echo ""
        echo "### Avant migration"
        echo "1. **Sauvegarder** tous les fichiers de cet audit"
        echo "2. **Documenter** les mots de passe utilisateurs"
        echo "3. **Exporter** les certificats SSL si utilisés"
        echo "4. **Noter** les applications critiques à réinstaller"
        echo "5. **Sauvegarder** les scripts personnalisés"
        echo ""
        
        echo "### Configuration à reproduire"
        echo "- Configuration des partages SMB/NFS"
        echo "- Comptes utilisateurs et permissions"
        echo "- Services réseau activés"
        echo "- Tâches planifiées importantes"
        echo "- Applications et leurs configurations"
        echo ""
        
        echo "### Checklist migration"
        echo "- [ ] Sauvegarde complète des données"
        echo "- [ ] Export configuration utilisateurs"
        echo "- [ ] Sauvegarde certificats SSL"
        echo "- [ ] Documentation des partages"
        echo "- [ ] Liste des applications installées"
        echo "- [ ] Backup des scripts et tâches cron"
        echo "- [ ] Test de connectivité réseau"
        echo "- [ ] Validation post-migration"
        echo ""
        
        echo "---"
        echo ""
        echo "**Audit généré par:** Script d'audit Synology v$SCRIPT_VERSION"
        echo "**Date de génération:** $DATE"
        echo "**Fichiers de données:** $(ls -1 "$AUDIT_DIR"/*.txt 2>/dev/null | wc -l) fichiers d'audit"
        
    } > "$report"
    
    info "Rapport de synthèse généré: $(basename "$report")"
}

# Fonction pour afficher le menu interactif
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    AUDIT SYNOLOGY NAS v$SCRIPT_VERSION                     ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║  Choisissez une option d'audit:                                 ║"
    echo "║                                                                  ║"
    echo "║  1) Audit complet (recommandé)                                  ║"
    echo "║  2) Système et matériel                                         ║"
    echo "║  3) Utilisateurs et groupes                                     ║"
    echo "║  4) Services réseau                                             ║"
    echo "║  5) Partages et dossiers                                        ║"
    echo "║  6) Configuration réseau                                        ║"
    echo "║  7) Stockage et RAID                                            ║"
    echo "║  8) Applications et packages                                    ║"
    echo "║  9) Tâches planifiées                                          ║"
    echo "║ 10) Sécurité                                                    ║"
    echo "║ 11) Rapport de synthèse seulement                              ║"
    echo "║                                                                  ║"
    echo "║  0) Quitter                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Fonction pour créer l'archive finale
create_archive() {
    section "Création de l'archive finale"
    
    if command -v tar &> /dev/null; then
        local archive_name="synology_audit_${HOSTNAME}_$(date +%Y%m%d_%H%M%S).tar.gz"
        local archive_path="/tmp/$archive_name"
        
        tar -czf "$archive_path" -C "$(dirname "$AUDIT_DIR")" "$(basename "$AUDIT_DIR")" 2>/dev/null
        
        if [ -f "$archive_path" ]; then
            log "Archive créée: $archive_path"
            log "Taille archive: $(ls -lh "$archive_path" | awk '{print $5}')"
            echo ""
            info "💾 SAUVEGARDEZ cette archive avant toute migration !"
        else
            error "Échec création archive"
        fi
    else
        warning "tar non disponible, pas d'archive créée"
    fi
}

# Fonction principale
main() {
    # Si des arguments sont passés, mode non-interactif
    if [ $# -gt 0 ]; then
        init_audit
        
        case "$1" in
            "all"|"complet"|"complete")
                audit_system
                audit_users
                audit_services
                audit_shares
                audit_network
                audit_storage
                audit_applications
                audit_scheduled_tasks
                audit_security
                generate_summary_report
                create_archive
                ;;
            "system"|"systeme")
                audit_system
                ;;
            "users"|"utilisateurs")
                audit_users
                ;;
            "services")
                audit_services
                ;;
            "shares"|"partages")
                audit_shares
                ;;
            "network"|"reseau")
                audit_network
                ;;
            "storage"|"stockage")
                audit_storage
                ;;
            "apps"|"applications")
                audit_applications
                ;;
            "tasks"|"taches")
                audit_scheduled_tasks
                ;;
            "security"|"securite")
                audit_security
                ;;
            "report"|"rapport")
                generate_summary_report
                ;;
            *)
                echo "Usage: $0 [all|system|users|services|shares|network|storage|apps|tasks|security|report]"
                exit 1
                ;;
        esac
    else
        # Mode interactif
        while true; do
            show_menu
            read -p "Votre choix [0-11]: " choice
            
            case $choice in
                1)
                    init_audit
                    audit_system
                    audit_users
                    audit_services
                    audit_shares
                    audit_network
                    audit_storage
                    audit_applications
                    audit_scheduled_tasks
                    audit_security
                    generate_summary_report
                    create_archive
                    break
                    ;;
                2)
                    init_audit
                    audit_system
                    ;;
                3)
                    init_audit
                    audit_users
                    ;;
                4)
                    init_audit
                    audit_services
                    ;;
                5)
                    init_audit
                    audit_shares
                    ;;
                6)
                    init_audit
                    audit_network
                    ;;
                7)
                    init_audit
                    audit_storage
                    ;;
                8)
                    init_audit
                    audit_applications
                    ;;
                9)
                    init_audit
                    audit_scheduled_tasks
                    ;;
                10)
                    init_audit
                    audit_security
                    ;;
                11)
                    init_audit
                    generate_summary_report
                    ;;
                0)
                    echo "Au revoir !"
                    exit 0
                    ;;
                *)
                    echo "Choix invalide. Appuyez sur Entrée pour continuer..."
                    read
                    ;;
            esac
            
            if [ "$choice" != "0" ]; then
                echo ""
                echo "Audit terminé. Appuyez sur Entrée pour continuer..."
                read
            fi
        done
    fi
    
    # Affichage final
    echo ""
    section "AUDIT TERMINÉ"
    echo ""
    echo "📁 Répertoire des résultats: $AUDIT_DIR"
    if [ -f "$AUDIT_DIR/00_RAPPORT_SYNTHESE.md" ]; then
        echo "📄 Rapport principal: $AUDIT_DIR/00_RAPPORT_SYNTHESE.md"
    fi
    echo "📋 Log complet: $LOGFILE"
    echo ""
    echo "💡 Conseil: Sauvegardez le répertoire $AUDIT_DIR avant toute migration"
    echo ""
}

# Gestion d'interruption propre
trap 'echo ""; error "Audit interrompu par l'\''utilisateur"; exit 1' INT TERM

# Point d'entrée
main "$@"
