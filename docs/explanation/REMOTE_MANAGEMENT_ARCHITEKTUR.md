# Cross-Platform Remote Management

*Erstellt am: 2025-07-14*

## 🎯 Überblick

Dieses Dokument beschreibt die strategische Ausrichtung für die Remote-Verwaltung der gesamten IT-Infrastruktur vom Mac aus über VPN-Verbindungen und Claude Code Integration.

## 🏗️ Geräte-Architektur

### **Primary Device: Mac**
- **Rolle:** Hauptarbeitsplatz und Remote-Management-Zentrale
- **OS:** macOS mit Claude Code
- **Funktion:** Orchestrierung aller Remote-Systeme
- **Konnektivität:** VPN zu Firmennetzwerk, SSH zu allen Systemen

### **Secondary Device: Windows PC (Dienstlich)**
- **Rolle:** SQL Server → PostgreSQL Migration + Power BI Development
- **OS:** Windows 11 mit PowerShell 7
- **Aktueller Status:** Remote Desktop via Windows App
- **Ziel:** SSH + PowerShell Remoting vom Mac aus
- **Anwendungen:**
  - SQL Server Management Studio
  - PostgreSQL Tools
  - Power BI Desktop
  - pgAdmin
  - DBeaver

### **Tertiary Device: Ubuntu Server VM**
- **Rolle:** SaaS-Hosting-Plattform
- **OS:** Ubuntu Server 22.04 LTS
- **Host:** Hyper-V auf Windows PC
- **IP:** 10.0.0.30
- **SSH-Zugang:** ✅ Funktional von Windows PowerShell
- **Funktion:** Docker-Container, Web-Services, Datenbank-Backend

### **Quaternary Device: Pi 5 16GB (Home Lab)**
- **Rolle:** Development Bridge und Test-Environment
- **OS:** Raspberry Pi OS
- **Management:** Primär über Claude Code
- **Funktion:** IoT-Gateway, Development-Server, Backup-System

## 🌐 Use Cases und Workflows

### **1. SQL Server → PostgreSQL Migration**

#### **Aktuelle Situation:**
- SQL Server auf Windows PC
- Migration zu PostgreSQL geplant
- Power BI Reports müssen angepasst werden

#### **Remote-Management-Strategie:**
```bash
# Vom Mac aus via SSH zu Windows PC
ssh dbadmin@windows-pc.corp.local

# PowerShell-Session für SQL Server Management
Enter-PSSession -ComputerName localhost -Credential $cred

# PostgreSQL-Installation und -konfiguration
# Docker-Container auf Ubuntu VM starten
ssh dashboard@10.0.0.30 "docker run -d postgres:15"
```

#### **Workflow-Integration:**
1. **Schema-Analyse:** SQL Server Schemata remote analysieren
2. **Daten-Export:** Automatisierte Backup-Scripts über SSH
3. **PostgreSQL-Setup:** Container-Deployment auf Ubuntu VM
4. **Migration-Scripts:** Automatisierte Daten-Migration
5. **Power BI Anpassung:** Report-Datasources remote aktualisieren

### **2. SaaS-Hosting auf Ubuntu VM**

#### **Deployment-Pipeline:**
```bash
# Vom Mac aus via VPN + SSH
ssh dashboard@10.0.0.30

# Docker-Container Management
docker-compose up -d saas-application
docker logs saas-application

# Health-Monitoring via Claude Code
claude --add-dir ~/projects/saas-monitoring "Check Ubuntu VM status"
```

#### **Management-Tasks:**
- Container-Orchestrierung
- Database-Management (PostgreSQL)
- Backup-Strategien
- Log-Monitoring
- Performance-Optimierung

### **3. Power BI Remote Development**

#### **Hybrid-Ansatz:**
- **Remote Desktop:** Für GUI-intensive Power BI Entwicklung
- **SSH + PowerShell:** Für Datenquelle-Management
- **Git-Integration:** Report-Versionierung über Claude Code

```powershell
# Remote PowerShell für Power BI Service Management
Invoke-Command -ComputerName windows-pc -ScriptBlock {
    # Power BI Dataset Refresh
    Invoke-PowerBIRestMethod -Url "datasets/refresh" -Method Post
    
    # Connection String Update für PostgreSQL
    $connectionString = "Host=10.0.0.30;Database=saas_db;Username=powerbi"
    Set-PowerBIDataSource -ConnectionString $connectionString
}
```

## 🔐 Sicherheits-Architektur

### **VPN-Konnektivität**
- **Firmennetzwerk:** Zugang zu Windows PC über VPN
- **SSH-Tunneling:** Sichere Verbindungen über verschlüsselte Tunnel
- **Key-Management:** Zentrale SSH-Keys auf Mac mit Verteilung

### **SSH-Key-Distribution**
```bash
# SSH-Key vom Mac zu Windows PC
ssh-copy-id dbadmin@windows-pc.corp.local

# SSH-Key zu Ubuntu VM (via Windows PC)
ssh dbadmin@windows-pc.corp.local
ssh-copy-id dashboard@10.0.0.30

# SSH-Key zu Pi 5 (direkt von Mac)
ssh-copy-id pi@pi5.home.local
```

### **Firewall und Port-Management**
- **Windows PC:** PowerShell Remoting (Port 5985/5986)
- **Ubuntu VM:** SSH (Port 22), PostgreSQL (Port 5432)
- **Pi 5:** SSH (Port 22), Custom Services

## 🤖 Claude Code Integration

### **Cross-Platform Workflows**

#### **SQL Migration mit Claude Code:**
```bash
# Claude Code Session für Migration-Planning
claude --add-dir ~/sql-migration "Analyze SQL Server schema and plan PostgreSQL migration"

# Automatisierte Schema-Conversion
claude -p "Convert this SQL Server schema to PostgreSQL: [schema-dump.sql]"

# Power BI Report Anpassung
claude --add-dir ~/powerbi-reports "Update these Power BI reports for PostgreSQL data source"
```

#### **SaaS-Deployment-Automation:**
```bash
# Ubuntu VM Health-Check
claude -p "SSH to 10.0.0.30 and check Docker container status, resource usage, and logs"

# Automated Deployment
claude --add-dir ~/saas-deployment "Deploy new version to Ubuntu VM with zero-downtime strategy"
```

#### **Pi 5 Integration:**
```bash
# Development Bridge Tasks
claude -p "Sync code from Windows development to Pi 5 test environment"

# IoT-Gateway Management
claude --add-dir ~/iot-projects "Check Pi 5 sensor data and update dashboard"
```

## 📊 Monitoring und Observability

### **Multi-System Health Dashboard**
- **Windows PC:** Performance Counters via PowerShell
- **Ubuntu VM:** System Metrics via SSH + Docker Stats
- **Pi 5:** Hardware-Status via SSH
- **Network:** VPN Status und Latency-Monitoring

### **Automated Reporting**
```bash
# Täglicher Status-Report via Claude Code
claude -p "Generate daily infrastructure report: Windows PC, Ubuntu VM, Pi 5 status"

# SQL Migration Progress-Tracking
claude --add-dir ~/migration-logs "Analyze migration progress and identify bottlenecks"
```

## 🚀 Implementation Roadmap

### **Phase 1: Network & SSH Setup**
1. **VPN-Konfiguration:** Stabile Verbindung zu Firmennetzwerk
2. **SSH-Access:** Windows PC SSH-Server aktivieren
3. **Key-Distribution:** Passwordless Authentication einrichten
4. **Firewall-Rules:** Sichere Port-Öffnung für Remote-Management

### **Phase 2: Remote Management Tools**
1. **PowerShell Remoting:** Windows PC Management vom Mac
2. **Ubuntu VM Integration:** Nahtloser SSH-Zugriff via Windows PC
3. **Claude Code Workflows:** Automatisierte Cross-Platform-Tasks
4. **Monitoring-Scripts:** Health-Checks für alle Systeme

### **Phase 3: SQL Migration Automation**
1. **Schema-Analysis-Tools:** Automatisierte SQL Server Inventarisierung
2. **PostgreSQL-Setup:** Container-Deployment auf Ubuntu VM
3. **Migration-Pipeline:** ETL-Prozesse mit Claude Code Integration
4. **Power BI Integration:** Datasource-Migration und Report-Updates

### **Phase 4: SaaS-Platform Optimization**
1. **CI/CD-Pipeline:** Automated Deployment zu Ubuntu VM
2. **Container-Orchestration:** Docker Swarm oder Kubernetes
3. **Database-Clustering:** PostgreSQL High-Availability
4. **Backup-Strategies:** Cross-System Backup-Automation

## 📋 Nächste Schritte

### **Sofortige Maßnahmen:**
1. **VPN-Setup testen:** Stabile Verbindung zu Firmennetzwerk etablieren
2. **SSH-Server auf Windows PC:** OpenSSH Server aktivieren und konfigurieren
3. **SSH-Keys generieren:** Key-Pair auf Mac erstellen und verteilen
4. **PowerShell Remoting:** WinRM konfigurieren für Remote-Management

### **Kurzzeitige Ziele (1-2 Wochen):**
1. **Claude Code Remote-Workflows:** Erste automatisierte Tasks implementieren
2. **Ubuntu VM Optimization:** Docker-Environment für SaaS-Hosting optimieren
3. **SQL Server Inventarisierung:** Bestehende Schemas und Daten analysieren
4. **Power BI Assessment:** Report-Dependencies und Migration-Aufwand bewerten

### **Mittelfristige Ziele (1-2 Monate):**
1. **PostgreSQL Migration:** Pilot-Migration für ausgewählte Datenbanken
2. **SaaS MVP-Deployment:** Erste Service-Container auf Ubuntu VM
3. **Monitoring-Dashboard:** Zentrale Übersicht aller Systeme
4. **Backup-Strategy:** Automatisierte Cross-System-Backups

## 🔗 Related Documents


---

**Aktualisierungsfrequenz:** Bei Änderungen der Infrastruktur oder neuen Remote-Management-Anforderungen  
**Verantwortlich:** Remote Management via Claude Code vom Mac aus  
**Status:** Initial Planning Phase