# Script d'audit Synology NAS

## 📋 Description

Script complet d'audit et de documentation pour NAS Synology. Génère un inventaire exhaustif de votre configuration système, utilisateurs, partages, services et sécurité pour faciliter les migrations, audits de conformité ou diagnostics système.

## ✨ Fonctionnalités

- **Audit complet automatisé** - Documentation de tous les aspects du NAS
- **Interface interactive** - Menu convivial avec navigation simple
- **Mode ligne de commande** - Intégration dans scripts et automatisation
- **Rapport de synthèse** - Vue d'ensemble formatée en Markdown
- **Archive portable** - Sauvegarde complète compressée
- **Logs détaillés** - Traçabilité complète des opérations

## 🎯 Cas d'usage

- **Migration NAS** - Documentation avant changement de matériel
- **Audit de conformité** - Inventaire système complet
- **Sauvegarde configuration** - Snapshot de l'état actuel
- **Diagnostic système** - Analyse complète pour troubleshooting
- **Documentation IT** - Inventaire pour équipe technique

## 📋 Prérequis

### Système requis
- **NAS Synology** avec DSM 6.0 ou supérieur
- **Accès SSH** activé
- **Compte administrateur** ou privilèges sudo
- **Espace disque** : ~50MB libres dans /tmp

### Dépendances
Les commandes suivantes sont utilisées si disponibles :
- `synouser` (utilisateurs DSM)
- `smartctl` (santé disques)
- `docker` (conteneurs)
- `netstat` ou `ss` (connexions réseau)
- `iptables` (firewall)

> ⚠️ **Note** : Le script fonctionne même si certaines commandes ne sont pas disponibles

## 🚀 Installation

### Méthode 1 : Téléchargement direct
```bash
# Connexion SSH au NAS
ssh admin@IP_SYNOLOGY

# Téléchargement du script
wget https://[URL_DU_SCRIPT]/synology_audit.sh

# Permissions d'exécution
chmod +x synology_audit.sh
```

### Méthode 2 : Copie manuelle
```bash
# Copier le script depuis votre PC
scp synology_audit.sh admin@IP_SYNOLOGY:/tmp/

# Connexion et permissions
ssh admin@IP_SYNOLOGY
chmod +x /tmp/synology_audit.sh
```

## 📖 Utilisation

### Mode interactif (recommandé)

```bash
./synology_audit.sh
```

Interface avec menu numéroté :
```
╔══════════════════════════════════════════════════════════════════╗
║                    AUDIT SYNOLOGY NAS v1.0                      ║
╠══════════════════════════════════════════════════════════════════╣
║  1) Audit complet (recommandé)                                  ║
║  2) Système et matériel                                         ║
║  3) Utilisateurs et groupes                                     ║
║  ...                                                             ║
║  0) Quitter                                                      ║
╚══════════════════════════════════════════════════════════════════╝
```

### Mode ligne de commande

```bash
# Audit complet (recommandé)
./synology_audit.sh all

# Audits spécifiques
./synology_audit.sh system      # Système et matériel
./synology_audit.sh users       # Utilisateurs et groupes  
./synology_audit.sh services    # Services réseau
./synology_audit.sh shares      # Partages SMB/NFS
./synology_audit.sh network     # Configuration réseau
./synology_audit.sh storage     # Stockage et RAID
./synology_audit.sh apps        # Applications installées
./synology_audit.sh tasks       # Tâches planifiées
./synology_audit.sh security    # Configuration sécurité
./synology_audit.sh report      # Rapport de synthèse uniquement
```

### Exemples d'usage

```bash
# Audit avant migration (complet)
./synology_audit.sh all

# Audit rapide utilisateurs seulement
./synology_audit.sh users

# Audit sécurité pour audit de conformité
./synology_audit.sh security

# Génération rapport sur audit existant
./synology_audit.sh report
```

## 📁 Structure des résultats

### Répertoire d'audit
```
/tmp/synology_audit_YYYYMMDD_HHMMSS/
├── 00_RAPPORT_SYNTHESE.md          # 📄 Rapport principal avec recommandations
├── 01_system_hardware.txt          # 🖥️ Informations système et matériel
├── 02_users_groups.txt             # 👥 Utilisateurs, groupes et permissions
├── 03_network_services.txt         # 🌐 Services réseau et ports ouverts
├── 04_shares_folders.txt           # 📁 Partages SMB/NFS et dossiers
├── 05_network_config.txt           # ⚙️ Configuration réseau complète
├── 06_storage_raid.txt             # 💾 Stockage, RAID et santé disques
├── 07_applications_packages.txt    # 📦 Applications et packages installés
├── 08_scheduled_tasks.txt          # ⏰ Tâches planifiées et cron
├── 09_security_config.txt          # 🔒 Configuration sécurité
└── audit.log                       # 📋 Log complet de l'exécution
```

### Archive générée
```
synology_audit_HOSTNAME_YYYYMMDD_HHMMSS.tar.gz
```

## 📊 Contenu des audits

### 🖥️ Système et matériel (01)
- Version DSM et informations système
- Architecture processeur et mémoire
- Utilisation CPU et RAM
- Interfaces réseau disponibles
- Processus système principaux

### 👥 Utilisateurs et groupes (02)
- Comptes utilisateurs DSM
- Groupes et appartenances
- Dossiers home utilisateurs
- Permissions et droits d'accès
- Historique des connexions

### 🌐 Services réseau (03)
- Ports ouverts et services associés
- Configuration SSH, SMB, FTP, NFS
- Processus réseau actifs
- Services Synology spécifiques

### 📁 Partages et dossiers (04)
- Structure des volumes de stockage
- Configuration partages SMB/CIFS
- Exports NFS configurés
- Tailles et permissions des dossiers
- Analyse utilisation espace disque

### ⚙️ Configuration réseau (05)
- Interfaces et adresses IP
- Configuration DNS et routage
- Paramètres DHCP
- Règles firewall
- Tests de connectivité

### 💾 Stockage et RAID (06)
- Disques physiques et partitions
- Configuration RAID (mdstat)
- Santé des disques (SMART)
- Utilisation volumes et inodes
- Montages et fstab

### 📦 Applications et packages (07)
- Packages Synology installés
- Conteneurs Docker actifs
- Processus d'applications
- Ports d'applications ouverts
- Services système actifs

### ⏰ Tâches planifiées (08)
- Crontab utilisateur et système
- Scripts dans cron.d
- Tâches Synology spécifiques
- Scripts personnalisés trouvés

### 🔒 Configuration sécurité (09)
- Utilisateurs privilégiés
- Logs de sécurité et tentatives d'intrusion
- Certificats SSL installés
- Configuration firewall
- Permissions critiques (SUID/SGID)

## 📄 Rapport de synthèse

Le fichier `00_RAPPORT_SYNTHESE.md` contient :

- **Résumé exécutif** avec statistiques clés
- **Points d'attention** détectés automatiquement
- **Recommandations** pour migration/sauvegarde
- **Checklist** de migration complète
- **Informations techniques** essentielles

## ⚡ Temps d'exécution

| Type d'audit | Durée estimée | Taille résultats |
|---------------|---------------|------------------|
| Audit complet | 3-8 minutes | 2-10 MB |
| Système seul | 30 secondes | 100-500 KB |
| Utilisateurs | 15 secondes | 50-200 KB |
| Partages | 45 secondes | 200-1 MB |
| Stockage | 1-3 minutes | 500 KB-2 MB |

> **Note** : Les temps varient selon la taille du NAS et le nombre d'éléments configurés

## 💾 Sauvegarde des résultats

### Copie vers PC
```bash
# Télécharger l'archive complète
scp admin@IP_SYNOLOGY:/tmp/synology_audit_*.tar.gz ~/Desktop/

# Ou télécharger seulement le rapport
scp admin@IP_SYNOLOGY:/tmp/synology_audit_*/00_RAPPORT_SYNTHESE.md ~/
```

### Copie vers clé USB
```bash
# Si clé USB montée sur le NAS
cp /tmp/synology_audit_*.tar.gz /volumeUSB1/usbshare/
```

### Envoi par email (si configuré)
```bash
# Envoyer le rapport par email
mail -s "Audit NAS $(hostname)" admin@domain.com < /tmp/synology_audit_*/00_RAPPORT_SYNTHESE.md
```

## 🔧 Dépannage

### Problèmes courants

#### Erreur "Permission denied"
```bash
# Solution : Exécuter avec sudo
sudo ./synology_audit.sh all
```

#### Erreur "Command not found"
```bash
# Vérifier les permissions
ls -la synology_audit.sh
chmod +x synology_audit.sh
```

#### Espace disque insuffisant
```bash
# Vérifier l'espace libre
df -h /tmp
# Nettoyer si nécessaire
rm -rf /tmp/synology_audit_*
```

#### Script interrompu
```bash
# Les fichiers partiels restent dans /tmp
# Supprimer et relancer
rm -rf /tmp/synology_audit_*
./synology_audit.sh all
```

### Logs de débogage

```bash
# Consulter le log d'exécution
tail -f /tmp/synology_audit_*/audit.log

# Rechercher des erreurs
grep -i error /tmp/synology_audit_*/audit.log
```

### Commandes de diagnostic
```bash
# Vérifier les dépendances
which synouser smartctl docker netstat iptables

# Tester l'accès aux fichiers système
ls -la /etc/passwd /etc/samba/smb.conf /proc/mdstat

# Vérifier les permissions utilisateur
id
groups
```

## ⚠️ Limitations et considérations

### Informations NON collectées
- **🔐 Mots de passe** (volontairement exclus pour sécurité)
- **🎫 Clés de licence** applications payantes  
- **🔑 Certificats privés** SSL/TLS
- **⚙️ Configurations** applications tierces spécifiques
- **📊 Données utilisateur** (contenu des fichiers)

### Sécurité et confidentialité
- Aucun mot de passe n'est collecté ou affiché
- Les logs système peuvent contenir des informations sensibles
- Sauvegarder les résultats en lieu sûr
- Supprimer les fichiers temporaires après usage

### Compatibilité
- **DSM 6.0+** : Entièrement supporté
- **DSM 5.x** : Support partiel (certaines commandes peuvent échouer)
- **DSM 7.x** : Entièrement supporté
- **Modèles anciens** : Certaines fonctions SMART peuvent ne pas fonctionner

## 📞 Support et contribution

### Signaler un problème
Si vous rencontrez des erreurs ou comportements inattendus :

1. **Consulter** le fichier `audit.log` généré
2. **Vérifier** les prérequis et permissions
3. **Tester** avec un audit spécifique plutôt que complet
4. **Documenter** le modèle NAS et version DSM

### Améliorer le script
Contributions bienvenues pour :
- Support nouveaux modèles NAS
- Amélioration détection automatique
- Nouveaux modules d'audit
- Optimisation performances
- Traductions

## 📚 Ressources complémentaires

### Documentation Synology
- [Guide DSM](https://www.synology.com/support/documentation)
- [API Synology](https://global.download.synology.com/download/Document/Software/DeveloperGuide/)
- [Commandes CLI](https://help.synology.com/developer-guide)

### Outils complémentaires
- **Synology Assistant** - Découverte réseau
- **DSM Mobile** - Gestion à distance
- **Active Backup** - Solutions de sauvegarde

## 📋 Checklist d'utilisation

### Avant audit
- [ ] SSH activé sur le NAS
- [ ] Compte admin accessible
- [ ] Espace disque suffisant (/tmp)
- [ ] Script téléchargé et exécutable

### Pendant audit
- [ ] Connexion SSH stable
- [ ] Éviter interruptions (Ctrl+C)
- [ ] Surveiller messages d'erreur
- [ ] Noter durée pour audits futurs

### Après audit
- [ ] Consulter rapport de synthèse
- [ ] Sauvegarder archive générée
- [ ] Vérifier complétude des données
- [ ] Nettoyer fichiers temporaires
- [ ] Documenter mots de passe séparément

---

## 📝 License et avertissements

Ce script est fourni "tel quel" sans garantie. L'utilisateur est responsable de :
- Vérifier la compatibilité avec son système
- Sauvegarder ses données avant utilisation
- Respecter les politiques de sécurité de son organisation
- Protéger les informations sensibles collectées

**Version** : 1.0  
**Dernière mise à jour** : Juin 2025
