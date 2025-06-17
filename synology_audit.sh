#!/bin/bash

# =================================================================
# Script d'audit complet Synology RS814+ pour migration UGREEN
# Usage: ./synology_audit.sh
# Exécuter en SSH sur le RS814+ en tant qu'admin
# =================================================================

# Configuration
AUDIT_DIR="synology_audit_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="audit.log"

# Couleurs pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$AUDIT_DIR/$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$AUDIT_DIR/$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$AUDIT_DIR/$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$AUDIT_DIR/$LOG_FILE"
}

# Fonction pour exécuter une commande avec gestion d'erreur et timeout
execute_cmd() {
    local cmd="$1"
    local output_file="$2"
    local description="$3"
    local timeout_sec="${4:-60}"  # Timeout par défaut: 60 secondes
    
    print_status "Collecte: $description"
    
    # Utiliser timeout pour éviter les blocages
    if timeout "$timeout_sec" bash -c "$cmd" > "$AUDIT_DIR/$output_file" 2>/dev/null; then
        print_success "$description -> $output_file"
    elif [ $? -eq 124 ]; then
        print_warning "Timeout ($timeout_sec s): $description"
        echo "TIMEOUT: Commande trop longue ($cmd)" > "$AUDIT_DIR/$output_file"
    else
        print_warning "Échec: $description"
        echo "ERREUR: Impossible d'exécuter $cmd" > "$AUDIT_DIR/$output_file"
    fi
}

# Vérification des prérequis
check_prerequisites() {
    print_status "Vérification des prérequis..."
    
    # Vérifier qu'on est sur Synology
    if [ ! -f /etc/synoinfo.conf ]; then
        print_error "Ce script doit être exécuté sur un Synology NAS"
        exit 1
    fi
    
    # Vérifier les permissions
    if [ "$(id -u)" -eq 0 ]; then
        print_warning "Exécution en tant que root détectée"
    elif groups | grep -q administrators; then
        print_success "Utilisateur administrateur détecté"
    else
        print_error "Droits administrateur requis"
        exit 1
    fi
    
    # Vérifier l'espace disque disponible
    AVAILABLE_SPACE=$(df /tmp | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 100000 ]; then
        print_warning "Espace disque limité dans /tmp ($AVAILABLE_SPACE Ko)"
    fi
}

# Création du répertoire d'audit
create_audit_directory() {
    print_status "Création du répertoire d'audit: $AUDIT_DIR"
    
    if mkdir -p "$AUDIT_DIR"; then
        print_success "Répertoire créé: $PWD/$AUDIT_DIR"
    else
        print_error "Impossible de créer le répertoire d'audit"
        exit 1
    fi
}

# Collecte des informations système
collect_system_info() {
    print_status "=== COLLECTE INFORMATIONS SYSTÈME ==="
    
    execute_cmd "cat /etc/synoinfo.conf" "synoinfo.conf" "Configuration Synology"
    execute_cmd "uname -a" "system_uname.txt" "Informations noyau"
    execute_cmd "cat /proc/version" "system_version.txt" "Version système"
    execute_cmd "uptime" "system_uptime.txt" "Uptime système"
    execute_cmd "date" "system_date.txt" "Date et heure système"
    execute_cmd "hostname" "system_hostname.txt" "Nom d'hôte"
}

# Collecte des informations matériel
collect_hardware_info() {
    print_status "=== COLLECTE INFORMATIONS MATÉRIEL ==="
    
    execute_cmd "cat /proc/cpuinfo" "hardware_cpu.txt" "Informations processeur"
    execute_cmd "cat /proc/meminfo" "hardware_memory.txt" "Informations mémoire"
    execute_cmd "cat /proc/interrupts" "hardware_interrupts.txt" "Interruptions matériel"
    execute_cmd "lsusb" "hardware_usb.txt" "Périphériques USB"
    execute_cmd "cat /proc/partitions" "hardware_partitions.txt" "Partitions disques"
    execute_cmd "fdisk -l" "hardware_fdisk.txt" "Table des partitions"
}

# Collecte des informations stockage - VERSION RAPIDE
collect_storage_info_fast() {
    print_status "=== COLLECTE STOCKAGE (informations critiques) ==="
    
    execute_cmd "df -h" "storage_df.txt" "Espace disque"
    execute_cmd "cat /proc/mdstat" "storage_raid.txt" "Statut RAID"
    execute_cmd "ls -la /volume1/" "storage_volume1_structure.txt" "Structure /volume1"
    
    # Seulement la taille totale de /volume1 (rapide)
    execute_cmd "du -sh /volume1" "storage_volume1_total.txt" "Taille totale /volume1"
    
    # Compter seulement les dossiers principaux (niveau 1)
    if [ -d /volume1 ]; then
        print_status "Comptage rapide des dossiers principaux..."
        for dir in /volume1/*/; do
            if [ -d "$dir" ]; then
                dirname=$(basename "$dir")
                echo "$dirname: dossier détecté" >> "$AUDIT_DIR/storage_folders_detected.txt"
            fi
        done 2>/dev/null
        print_success "Dossiers détectés -> storage_folders_detected.txt"
    fi
}

# Collecte stockage - TAILLES PRINCIPALES SEULEMENT
collect_storage_info_sizes_only() {
    print_status "=== COLLECTE TAILLES PRINCIPALES ==="
    
    # Utiliser timeout pour éviter les blocages
    execute_cmd "timeout 300 du -sh /volume1/* 2>/dev/null || echo 'Timeout - calcul partiel'" "storage_volume1_sizes.txt" "Tailles dossiers /volume1 (avec timeout)"
    
    # Top 10 des plus gros dossiers (rapide)
    if [ -d /volume1 ]; then
        print_status "Identification des plus gros dossiers..."
        timeout 180 find /volume1 -maxdepth 2 -type d -exec du -sh {} \; 2>/dev/null | sort -hr | head -20 > "$AUDIT_DIR/storage_top_folders.txt"
        print_success "Top dossiers -> storage_top_folders.txt"
    fi
}

# Collecte stockage - VERSION DÉTAILLÉE (longue)
collect_storage_info_detailed() {
    print_status "=== COLLECTE STOCKAGE DÉTAILLÉE (peut prendre du temps) ==="
    
    execute_cmd "timeout 600 du -sh /volume1/*" "storage_volume1_sizes_detailed.txt" "Tailles détaillées /volume1"
    execute_cmd "timeout 300 find /volume1 -maxdepth 1 -type d -exec du -sh {} \;" "storage_volume1_breakdown.txt" "Répartition détaillée /volume1"
    
    # Compter les fichiers par dossier avec timeout
    if [ -d /volume1 ]; then
        print_status "Comptage détaillé des fichiers (long)..."
        for dir in /volume1/*/; do
            if [ -d "$dir" ]; then
                dirname=$(basename "$dir")
                print_status "Comptage: $dirname..."
                filecount=$(timeout 60 find "$dir" -type f 2>/dev/null | wc -l)
                if [ $? -eq 124 ]; then
                    echo "$dirname: >timeout (beaucoup de fichiers)" >> "$AUDIT_DIR/storage_file_counts_detailed.txt"
                else
                    echo "$dirname: $filecount fichiers" >> "$AUDIT_DIR/storage_file_counts_detailed.txt"
                fi
            fi
        done
        print_success "Comptage détaillé -> storage_file_counts_detailed.txt"
    fi
    
    # Analyse des types de fichiers (échantillon)
    print_status "Analyse types de fichiers (échantillon)..."
    timeout 120 find /volume1 -type f -name "*.*" 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -20 > "$AUDIT_DIR/storage_file_types.txt"
    print_success "Types de fichiers -> storage_file_types.txt"
}

# Collecte des informations réseau
collect_network_info() {
    print_status "=== COLLECTE INFORMATIONS RÉSEAU ==="
    
    execute_cmd "ifconfig" "network_interfaces.txt" "Interfaces réseau"
    execute_cmd "ip route" "network_routes.txt" "Table de routage"
    execute_cmd "cat /etc/resolv.conf" "network_dns.txt" "Configuration DNS"
    execute_cmd "netstat -tuln" "network_ports.txt" "Ports ouverts"
    execute_cmd "netstat -rn" "network_routing.txt" "Routage réseau"
}

# Collecte des informations utilisateurs
collect_user_info() {
    print_status "=== COLLECTE INFORMATIONS UTILISATEURS ==="
    
    execute_cmd "cat /etc/passwd" "users_passwd.txt" "Liste utilisateurs"
    execute_cmd "cat /etc/group" "users_groups.txt" "Liste groupes"
    execute_cmd "cat /etc/shadow" "users_shadow.txt" "Mots de passe (hash)"
    execute_cmd "ls -la /volume1/homes/" "users_homes.txt" "Dossiers utilisateurs"
    
    # Permissions spéciales
    execute_cmd "getfacl /volume1/* 2>/dev/null || echo 'ACL non supporté'" "users_acl.txt" "ACL dossiers"
}

# Collecte des informations services
collect_services_info() {
    print_status "=== COLLECTE INFORMATIONS SERVICES ==="
    
    execute_cmd "/usr/syno/bin/synosystemctl list-units" "services_systemctl.txt" "Services système"
    execute_cmd "ps aux" "services_processes.txt" "Processus actifs"
    execute_cmd "cat /etc/ssh/sshd_config" "services_ssh_config.txt" "Configuration SSH"
    
    # Services Synology spécifiques
    execute_cmd "/usr/syno/bin/synosystemctl status sshd" "services_ssh_status.txt" "Statut SSH"
    execute_cmd "/usr/syno/bin/synosystemctl status smbd" "services_smb_status.txt" "Statut SMB"
    execute_cmd "/usr/syno/bin/synosystemctl status nmbd" "services_nmb_status.txt" "Statut NetBIOS"
}

# Collecte des informations packages/applications
collect_packages_info() {
    print_status "=== COLLECTE INFORMATIONS PACKAGES ==="
    
    # Packages installés
    if [ -d /var/packages ]; then
        execute_cmd "ls -la /var/packages/" "packages_list.txt" "Liste packages" 10
        execute_cmd "find /var/packages -name 'INFO' -exec basename \$(dirname {}) \; | sort" "packages_names.txt" "Noms packages" 30
        
        # Détail des packages (rapide)
        print_status "Collecte détails packages..."
        for pkg in /var/packages/*/; do
            if [ -f "$pkg/INFO" ]; then
                pkg_name=$(basename "$pkg")
                echo "=== $pkg_name ===" >> "$AUDIT_DIR/packages_details.txt"
                cat "$pkg/INFO" >> "$AUDIT_DIR/packages_details.txt" 2>/dev/null
                echo "" >> "$AUDIT_DIR/packages_details.txt"
            fi
        done
        print_success "Détails packages -> packages_details.txt"
    fi
    
    # Docker si présent (avec timeout court)
    if command -v docker >/dev/null 2>&1; then
        execute_cmd "docker ps -a" "docker_containers.txt" "Conteneurs Docker" 15
        execute_cmd "docker images" "docker_images.txt" "Images Docker" 15
        execute_cmd "docker version" "docker_version.txt" "Version Docker" 5
    fi
}

# Collecte des logs
collect_logs() {
    print_status "=== COLLECTE LOGS SYSTÈME (échantillon) ==="
    
    execute_cmd "tail -500 /var/log/messages" "logs_messages.txt" "Messages système récents" 30
    execute_cmd "dmesg | tail -200" "logs_dmesg.txt" "Messages noyau récents" 10
    
    # Logs Synology spécifiques
    if [ -d /var/log/synolog ]; then
        execute_cmd "ls -la /var/log/synolog/" "logs_synology_list.txt" "Logs Synology disponibles" 5
        # Seulement un échantillon des logs les plus récents
        execute_cmd "find /var/log/synolog -name '*.log' -exec tail -100 {} \;" "logs_synology_sample.txt" "Échantillon logs Synology" 60
    fi
}

# Collecte des configurations critiques
collect_configs() {
    print_status "=== COLLECTE CONFIGURATIONS ==="
    
    execute_cmd "cat /etc/fstab" "config_fstab.txt" "Points de montage"
    execute_cmd "crontab -l" "config_crontab.txt" "Tâches cron"
    execute_cmd "cat /etc/hosts" "config_hosts.txt" "Fichier hosts"
    
    # Configuration Samba/SMB
    if [ -f /etc/samba/smb.conf ]; then
        execute_cmd "cat /etc/samba/smb.conf" "config_smb.txt" "Configuration SMB"
    fi
    
    # Configuration réseau avancée
    if [ -f /etc/dhcpd/dhcpd.conf ]; then
        execute_cmd "cat /etc/dhcpd/dhcpd.conf" "config_dhcp.txt" "Configuration DHCP"
    fi
}

# Génération du rapport final
generate_report() {
    print_status "=== GÉNÉRATION RAPPORT FINAL ==="
    
    REPORT_FILE="$AUDIT_DIR/RAPPORT_AUDIT.txt"
    
    cat > "$REPORT_FILE" << EOF
========================================
RAPPORT D'AUDIT SYNOLOGY RS814+
========================================
Date: $(date)
Hostname: $(hostname)
Système: $(cat /proc/version 2>/dev/null || echo "Inconnu")

========================================
RÉSUMÉ STOCKAGE
========================================
EOF
    
    if [ -f "$AUDIT_DIR/storage_df.txt" ]; then
        echo "=== Espace disque ===" >> "$REPORT_FILE"
        cat "$AUDIT_DIR/storage_df.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [ -f "$AUDIT_DIR/storage_volume1_total.txt" ]; then
        echo "=== Taille totale /volume1 ===" >> "$REPORT_FILE"
        cat "$AUDIT_DIR/storage_volume1_total.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [ -f "$AUDIT_DIR/storage_volume1_sizes.txt" ]; then
        echo "=== Tailles dossiers /volume1 ===" >> "$REPORT_FILE"
        cat "$AUDIT_DIR/storage_volume1_sizes.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    elif [ -f "$AUDIT_DIR/storage_top_folders.txt" ]; then
        echo "=== Top 10 plus gros dossiers ===" >> "$REPORT_FILE"
        head -10 "$AUDIT_DIR/storage_top_folders.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [ -f "$AUDIT_DIR/storage_file_counts.txt" ]; then
        echo "=== Nombre de fichiers ===" >> "$REPORT_FILE"
        cat "$AUDIT_DIR/storage_file_counts.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    elif [ -f "$AUDIT_DIR/storage_folders_detected.txt" ]; then
        echo "=== Dossiers détectés ===" >> "$REPORT_FILE"
        cat "$AUDIT_DIR/storage_folders_detected.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

========================================
RÉSUMÉ UTILISATEURS
========================================
EOF
    
    if [ -f "$AUDIT_DIR/users_passwd.txt" ]; then
        echo "=== Utilisateurs système ===" >> "$REPORT_FILE"
        grep -E "(admin|users|homes)" "$AUDIT_DIR/users_passwd.txt" >> "$REPORT_FILE" 2>/dev/null
        echo "" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

========================================
RÉSUMÉ SERVICES
========================================
EOF
    
    if [ -f "$AUDIT_DIR/services_systemctl.txt" ]; then
        echo "=== Services actifs ===" >> "$REPORT_FILE"
        grep -i "active\|running" "$AUDIT_DIR/services_systemctl.txt" | head -20 >> "$REPORT_FILE" 2>/dev/null
        echo "" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

========================================
FICHIERS GÉNÉRÉS
========================================
EOF
    
    ls -la "$AUDIT_DIR/" >> "$REPORT_FILE"
    
    print_success "Rapport généré -> $REPORT_FILE"
}

# Création de l'archive finale
create_archive() {
    print_status "=== CRÉATION ARCHIVE ==="
    
    ARCHIVE_NAME="synology_audit_$(hostname)_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if tar -czf "$ARCHIVE_NAME" "$AUDIT_DIR/"; then
        print_success "Archive créée: $PWD/$ARCHIVE_NAME"
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    AUDIT TERMINÉ AVEC SUCCÈS                ║${NC}"
        echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║${NC} Archive finale: $ARCHIVE_NAME"
        echo -e "${GREEN}║${NC} Dossier détail: $AUDIT_DIR/"
        echo -e "${GREEN}║${NC} Rapport principal: $AUDIT_DIR/RAPPORT_AUDIT.txt"
        echo -e "${GREEN}║${NC}"
        echo -e "${GREEN}║${NC} Prochaines étapes:"
        echo -e "${GREEN}║${NC} 1. Téléchargez l'archive sur votre PC"
        echo -e "${GREEN}║${NC} 2. Consultez le rapport principal"
        echo -e "${GREEN}║${NC} 3. Procédez à la configuration du DXP4800+"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        print_error "Échec création archive"
    fi
}

# Fonction principale
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  AUDIT RAPIDE SYNOLOGY RS814+"
    echo "  Version: 1.1 - Optimisé"
    echo "  Date: $(date)"
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}⏱️  TEMPS ESTIMÉS:${NC}"
    echo -e "   Phase 1 (Critiques):     ${YELLOW}2-3 minutes${NC}"
    echo -e "   Phase 2 (Importantes):   ${YELLOW}1-2 minutes${NC}"
    echo -e "   Phase 3 (Stockage):      ${YELLOW}30 sec - 30 min (au choix)${NC}"
    echo -e "   Phase 4 (Logs):          ${YELLOW}30 secondes${NC}"
    echo ""
    echo -e "${GREEN}📊 L'audit s'adapte à vos besoins:${NC}"
    echo -e "   • ${GREEN}Rapide${NC}: Infos essentielles seulement (5 min)"
    echo -e "   • ${YELLOW}Standard${NC}: + tailles principales (10 min)"  
    echo -e "   • ${RED}Complet${NC}: + analyse détaillée (30+ min)"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    echo ""
    
    check_prerequisites
    create_audit_directory
    
    # PHASE 1: Infos critiques et rapides (1-2 minutes)
    print_status "=== PHASE 1: INFORMATIONS CRITIQUES (rapide) ==="
    collect_system_info
    collect_user_info
    collect_services_info
    collect_network_info
    
    # PHASE 2: Infos importantes (2-3 minutes)
    print_status "=== PHASE 2: INFORMATIONS IMPORTANTES ==="
    collect_hardware_info
    collect_packages_info
    collect_configs
    
    # PHASE 3: Stockage rapide puis détaillé (optionnel)
    print_status "=== PHASE 3: INFORMATIONS STOCKAGE ==="
    collect_storage_info_fast
    
    echo ""
    echo -e "${YELLOW}Voulez-vous continuer avec l'analyse DÉTAILLÉE du stockage ? (peut prendre 10-30 min)${NC}"
    echo -e "${YELLOW}[O]ui / [N]on / [S]eulement tailles principales${NC}"
    read -t 30 -p "Choix (défaut: S): " storage_choice
    storage_choice=${storage_choice:-S}
    
    case "$storage_choice" in
        [Oo]|[Oo]ui)
            collect_storage_info_detailed
            ;;
        [Ss]|[Ss]eulement)
            collect_storage_info_sizes_only
            ;;
        *)
            print_status "Analyse détaillée du stockage ignorée"
            ;;
    esac
    
    # PHASE 4: Logs (rapide)
    collect_logs
    
    generate_report
    create_archive
    
    print_status "Nettoyage des fichiers temporaires..."
    # Optionnel: supprimer le dossier non archivé
    # rm -rf "$AUDIT_DIR"
    
    echo ""
    print_success "Audit terminé ! Consultez le fichier RAPPORT_AUDIT.txt"
}

# Gestion des signaux
trap 'print_error "Script interrompu"; exit 1' INT TERM

# Exécution du script principal
main "$@"
