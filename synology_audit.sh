#!/bin/bash

# Script d'audit Synology optimisé pour compatibilité maximale
# Version rapide sans commandes problématiques

set -e

# Configuration
AUDIT_DIR="/tmp/synology_audit_fast_$(date +%Y%m%d_%H%M%S)"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Initialisation
init_audit() {
    mkdir -p "$AUDIT_DIR"
    echo "=== AUDIT SYNOLOGY RAPIDE ==="
    log "Hostname: $HOSTNAME"
    log "Date: $DATE"
    log "Répertoire: $AUDIT_DIR"
    echo ""
}

# 1. Informations système essentielles
audit_system_fast() {
    local output="$AUDIT_DIR/system_info.txt"
    log "Collecte informations système..."
    
    {
        echo "=== INFORMATIONS SYSTÈME ==="
        echo "Date: $DATE"
        echo "Hostname: $HOSTNAME"
        echo ""
        
        echo "=== VERSION DSM ==="
        if [ -f /etc/VERSION ]; then
            cat /etc/VERSION
        elif [ -f /etc.defaults/VERSION ]; then
            cat /etc.defaults/VERSION
        else
            echo "Version DSM non trouvée"
        fi
        echo ""
        
        echo "=== SYSTÈME ==="
        echo "Architecture: $(uname -m)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime)"
        echo ""
        
        echo "=== MÉMOIRE ==="
        free -h 2>/dev/null || free
        echo ""
        
        echo "=== RÉSEAU ==="
        hostname -I 2>/dev/null || echo "IP non disponible"
        
    } > "$output"
    
    info "✅ Système: $(basename "$output")"
}

# 2. Stockage - LE PLUS IMPORTANT
audit_storage_fast() {
    local output="$AUDIT_DIR/storage_usage.txt"
    log "Analyse stockage (peut prendre 1-2 minutes)..."
    
    {
        echo "=== UTILISATION STOCKAGE ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== VOLUMES MONTÉS ==="
        df -h
        echo ""
        
        echo "=== ESPACE VOLUME1 ==="
        if [ -d /volume1 ]; then
            echo "Espace total volume1:"
            df -h /volume1
            echo ""
            
            echo "=== TOP 20 DOSSIERS LES PLUS LOURDS ==="
            echo "Calcul en cours..."
            timeout 120 du -sh /volume1/* 2>/dev/null | sort -hr | head -20 || echo "Timeout ou erreur - calcul partiel"
            echo ""
            
            echo "=== STRUCTURE VOLUME1 ==="
            ls -la /volume1/ 2>/dev/null | head -30
        else
            echo "Volume1 non trouvé"
        fi
        
    } > "$output"
    
    info "✅ Stockage: $(basename "$output")"
}

# 3. Utilisateurs
audit_users_fast() {
    local output="$AUDIT_DIR/users_config.txt"
    log "Collecte utilisateurs..."
    
    {
        echo "=== UTILISATEURS ET GROUPES ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== COMPTES UTILISATEURS ==="
        if command -v synouser &> /dev/null; then
            synouser --enum all 2>/dev/null || echo "Erreur synouser"
        else
            echo "Utilisateurs système (UID >= 1000):"
            awk -F: '$3 >= 1000 || $1 == "admin" {print $1 " (UID:" $3 ", Home:" $6 ")"}' /etc/passwd 2>/dev/null
        fi
        echo ""
        
        echo "=== DOSSIERS HOME ==="
        if [ -d /volume1/homes ]; then
            ls -la /volume1/homes/ 2>/dev/null
        else
            echo "Pas de dossier homes"
        fi
        echo ""
        
        echo "=== SESSIONS ACTUELLES ==="
        who 2>/dev/null || echo "Aucune session"
        
    } > "$output"
    
    info "✅ Utilisateurs: $(basename "$output")"
}

# 4. Partages SMB
audit_shares_fast() {
    local output="$AUDIT_DIR/smb_shares.txt"
    log "Analyse partages SMB..."
    
    {
        echo "=== CONFIGURATION PARTAGES SMB ==="
        echo "Date: $DATE"
        echo ""
        
        if [ -f /etc/samba/smb.conf ]; then
            echo "=== PARTAGES CONFIGURÉS ==="
            grep "^\[" /etc/samba/smb.conf | grep -v global
            echo ""
            
            echo "=== CONFIGURATION DÉTAILLÉE ==="
            awk '/^\[/{section=$0} /^[[:space:]]*(path|comment|valid users|read only)/{print section ": " $0}' /etc/samba/smb.conf 2>/dev/null
            echo ""
            
            echo "=== WORKGROUP ET SERVEUR ==="
            grep -E "(workgroup|server string)" /etc/samba/smb.conf 2>/dev/null || echo "Configuration standard"
        else
            echo "Fichier smb.conf non trouvé"
        fi
        
    } > "$output"
    
    info "✅ Partages: $(basename "$output")"
}

# 5. Services réseau
audit_services_fast() {
    local output="$AUDIT_DIR/network_services.txt"
    log "Analyse services réseau..."
    
    {
        echo "=== SERVICES RÉSEAU ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== PORTS OUVERTS ==="
        if command -v netstat &> /dev/null; then
            netstat -tlpn 2>/dev/null | grep LISTEN | while read line; do
                port=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
                process=$(echo "$line" | awk '{print $7}' | cut -d/ -f2 2>/dev/null || echo "unknown")
                echo "Port $port: $process"
            done
        else
            echo "netstat non disponible"
        fi
        echo ""
        
        echo "=== SERVICES PRINCIPAUX ==="
        echo "SSH: $(pgrep sshd > /dev/null && echo "Actif" || echo "Inactif")"
        echo "SMB: $(pgrep smbd > /dev/null && echo "Actif" || echo "Inactif")"
        echo "NFS: $(pgrep nfsd > /dev/null && echo "Actif" || echo "Inactif")"
        
    } > "$output"
    
    info "✅ Services: $(basename "$output")"
}

# 6. Applications installées
audit_apps_fast() {
    local output="$AUDIT_DIR/applications.txt"
    log "Inventaire applications..."
    
    {
        echo "=== APPLICATIONS INSTALLÉES ==="
        echo "Date: $DATE"
        echo ""
        
        echo "=== PACKAGES SYNOLOGY ==="
        if [ -d /var/packages ]; then
            echo "Packages détectés:"
            ls -1 /var/packages/ 2>/dev/null
            echo ""
            
            echo "Détails des packages principaux:"
            for pkg in /var/packages/*/INFO; do
                if [ -f "$pkg" ]; then
                    pkg_name=$(dirname "$pkg" | xargs basename)
                    version=$(grep "version=" "$pkg" 2>/dev/null | cut -d= -f2 | tr -d '"')
                    echo "$pkg_name: $version"
                fi
            done | head -20
        else
            echo "Aucun package trouvé"
        fi
        echo ""
        
        echo "=== DOCKER ==="
        if command -v docker &> /dev/null; then
            echo "Docker installé:"
            docker ps -a 2>/dev/null | wc -l || echo "Erreur Docker"
        else
            echo "Docker non installé"
        fi
        
    } > "$output"
    
    info "✅ Applications: $(basename "$output")"
}

# Génération du rapport de synthèse
generate_report_fast() {
    local report="$AUDIT_DIR/RAPPORT_MIGRATION.md"
    log "Génération rapport de synthèse..."
    
    {
        echo "# Audit Synology - Rapport de migration"
        echo ""
        echo "**Date:** $DATE"
        echo "**Système:** $HOSTNAME"
        echo ""
        
        echo "## 💾 Utilisation stockage"
        if [ -f "$AUDIT_DIR/storage_usage.txt" ]; then
            echo ""
            echo "### Espace volume1"
            grep -A3 "df -h /volume1" "$AUDIT_DIR/storage_usage.txt" | tail -1 || echo "Non disponible"
            echo ""
            
            echo "### Top 10 dossiers les plus lourds"
            echo '```'
            grep -A15 "TOP 20 DOSSIERS" "$AUDIT_DIR/storage_usage.txt" | head -15 || echo "Non calculé"
            echo '```'
        fi
        echo ""
        
        echo "## 📁 Partages SMB à recréer"
        if [ -f "$AUDIT_DIR/smb_shares.txt" ]; then
            echo ""
            echo "### Partages configurés"
            echo '```'
            grep "^\[" "$AUDIT_DIR/smb_shares.txt" | grep -v "===" || echo "Aucun partage trouvé"
            echo '```'
        fi
        echo ""
        
        echo "## 👥 Utilisateurs à reconfigurer"
        if [ -f "$AUDIT_DIR/users_config.txt" ]; then
            echo ""
            echo "### Comptes utilisateurs"
            echo '```'
            grep -A10 "COMPTES UTILISATEURS" "$AUDIT_DIR/users_config.txt" | tail -10 || echo "Non disponible"
            echo '```'
        fi
        echo ""
        
        echo "## 🌐 Services réseau actifs"
        if [ -f "$AUDIT_DIR/network_services.txt" ]; then
            echo ""
            echo "### Services principaux"
            echo '```'
            grep -A5 "SERVICES PRINCIPAUX" "$AUDIT_DIR/network_services.txt" | tail -5 || echo "Non disponible"
            echo '```'
        fi
        echo ""
        
        echo "## 📦 Applications installées"
        if [ -f "$AUDIT_DIR/applications.txt" ]; then
            echo ""
            echo "### Packages Synology"
            echo '```'
            grep -A10 "Packages détectés" "$AUDIT_DIR/applications.txt" | tail -10 || echo "Non disponible"
            echo '```'
        fi
        echo ""
        
        echo "## ✅ Checklist migration"
        echo ""
        echo "- [ ] **Espace disque DXP4800+** : Vérifier capacité suffisante"
        echo "- [ ] **Recréer partages SMB** dans interface UGOS"
        echo "- [ ] **Configurer utilisateurs** dans UGOS"
        echo "- [ ] **Activer services** (SSH, SMB, etc.)"
        echo "- [ ] **Réinstaller applications** nécessaires"
        echo "- [ ] **Tester connectivité** après migration"
        echo ""
        
        echo "---"
        echo "**Généré par:** Audit Synology Rapide"
        echo "**Fichiers:** $(ls -1 "$AUDIT_DIR"/*.txt | wc -l) fichiers de données"
        
    } > "$report"
    
    info "✅ Rapport: $(basename "$report")"
}

# Fonction principale
main() {
    init_audit
    
    audit_system_fast
    audit_storage_fast
    audit_users_fast
    audit_shares_fast
    audit_services_fast
    audit_apps_fast
    generate_report_fast
    
    # Archive
    if command -v tar &> /dev/null; then
        local archive="/tmp/synology_audit_fast_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$archive" -C "$(dirname "$AUDIT_DIR")" "$(basename "$AUDIT_DIR")" 2>/dev/null
        log "📦 Archive créée: $archive"
    fi
    
    echo ""
    echo "=== AUDIT RAPIDE TERMINÉ ==="
    echo ""
    echo "📁 Répertoire: $AUDIT_DIR"
    echo "📄 Rapport principal: $AUDIT_DIR/RAPPORT_MIGRATION.md"
    echo ""
    echo "💡 Sauvegardez ces fichiers avant migration !"
}

# Lancement
main "$@"
