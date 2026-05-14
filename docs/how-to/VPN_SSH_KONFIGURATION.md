# VPN + SSH Setup für Cross-Platform Remote Management

*Erstellt am: 2025-07-14*

## 🎯 Zielsetzung

Sichere VPN-Verbindung vom Mac zum Firmennetzwerk mit anschließendem SSH-Zugriff auf Windows PC und Ubuntu VM für vollständige Remote-Verwaltung.

## 🌐 Netzwerk-Architektur

### **Verbindungsweg:**
```
Mac (Home) 
  ↓ VPN
Firmennetzwerk
  ↓ RDP/SSH
Windows PC (Dienstlich)
  ↓ Hyper-V Network
Ubuntu VM (10.0.0.30)
```

### **Aktuelle Konfiguration:**
- **Windows PC:** Über Windows App (Remote Desktop) erreichbar
- **Ubuntu VM:** SSH funktionsfähig von Windows PowerShell
- **VPN:** Firmennetzwerk-Zugang vom Mac möglich

## 🔐 SSH-Setup für Windows PC

### **OpenSSH Server Installation**
```powershell
# Auf Windows PC ausführen
# Optional Features überprüfen
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

# OpenSSH Server installieren
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# SSH Server Service starten
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Firewall-Regel für SSH
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

### **SSH-Konfiguration optimieren**
```powershell
# SSH Server Konfiguration bearbeiten
notepad C:\ProgramData\ssh\sshd_config

# Wichtige Einstellungen:
# Port 22
# PasswordAuthentication yes (initial)
# PubkeyAuthentication yes
# AuthorizedKeysFile .ssh/authorized_keys
# Subsystem sftp sftp-server.exe

# Service nach Änderungen neu starten
Restart-Service sshd
```

## 🔑 SSH-Key Management

### **SSH-Keys auf Mac generieren**
```bash
# Ed25519 Key-Pair generieren (empfohlen)
ssh-keygen -t ed25519 -C "dbadmin@corp.local" -f ~/.ssh/id_ed25519_firma

# Oder RSA als Fallback
ssh-keygen -t rsa -b 4096 -C "dbadmin@corp.local" -f ~/.ssh/id_rsa_firma

# SSH-Agent Konfiguration
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_firma
```

### **Public Key zu Windows PC übertragen**
```bash
# Via VPN + SSH (nach initial setup)
ssh-copy-id -i ~/.ssh/id_ed25519_firma.pub dbadmin@windows-pc.corp.local

# Oder manual via Remote Desktop:
# 1. Public Key Inhalt kopieren
cat ~/.ssh/id_ed25519_firma.pub | pbcopy

# 2. Auf Windows PC in PowerShell:
mkdir -p C:\Users\dbadmin\.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... dbadmin@corp.local" >> C:\Users\dbadmin\.ssh\authorized_keys
```

### **SSH-Permissions auf Windows**
```powershell
# Auf Windows PC: Korrekte Berechtigungen setzen
icacls C:\Users\dbadmin\.ssh /inheritance:r
icacls C:\Users\dbadmin\.ssh /grant:r "%USERNAME%:(OI)(CI)(F)"
icacls C:\Users\dbadmin\.ssh\authorized_keys /inheritance:r
icacls C:\Users\dbadmin\.ssh\authorized_keys /grant:r "%USERNAME%:(F)"
```

## 🔧 SSH-Client Konfiguration auf Mac

### **SSH Config erstellen**
```bash
# ~/.ssh/config auf Mac
cat >> ~/.ssh/config << 'EOF'
# Corp Windows PC
Host windows-pc
    HostName windows-pc.corp.local
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_firma
    Port 22
    ForwardAgent yes
    Compression yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Ubuntu VM via Windows PC (SSH Jump)
Host ubuntu-vm
    HostName 10.0.0.30
    User dashboard
    ProxyJump windows-pc
    IdentityFile ~/.ssh/id_ed25519_firma
    Port 22
    ForwardAgent yes

# Pi 5 (Direct Connection)
Host pi5
    HostName pi5.home.local
    User pi
    IdentityFile ~/.ssh/id_ed25519_home
    Port 22
    ForwardAgent yes
EOF
```

### **SSH-Verbindungen testen**
```bash
# Direkte Verbindung zu Windows PC
ssh windows-pc

# SSH Jump zu Ubuntu VM
ssh ubuntu-vm

# PowerShell-Session über SSH
ssh windows-pc "powershell.exe -Command 'Get-ComputerInfo | Select-Object WindowsProductName, TotalPhysicalMemory'"
```

## 🌐 VPN-Konfiguration

### **VPN-Client Setup auf Mac**
```bash
# VPN-Verbindung über Network Preferences oder CLI
# Corp-spezifische VPN-Konfiguration erforderlich

# VPN-Status prüfen
ifconfig | grep -A 5 "utun"

# Route-Tabelle nach VPN-Verbindung
netstat -rn | grep "default"

# DNS-Resolution testen
nslookup windows-pc.corp.local
```

### **Automatisierte VPN-Verbindung**
```bash
# AppleScript für automatice VPN-Verbindung
cat > ~/Scripts/connect-corp-vpn.scpt << 'EOF'
tell application "System Events"
    tell current location of network preferences
        set VPNservice to service "Corp VPN"
        if exists VPNservice then connect VPNservice
    end tell
end tell
EOF

# Ausführbar machen
chmod +x ~/Scripts/connect-corp-vpn.scpt

# Alias in ~/.zshrc oder ~/.bash_profile
echo 'alias vpn-corp="osascript ~/Scripts/connect-corp-vpn.scpt"' >> ~/.zshrc
```

## 🔥 Firewall und Security

### **Windows PC Firewall-Regeln**
```powershell
# SSH-Port 22 für VPN-Subnetz öffnen
New-NetFirewallRule -DisplayName "SSH from VPN" -Direction Inbound -Protocol TCP -LocalPort 22 -RemoteAddress "10.0.0.0/8,172.16.0.0/12,10.0.0.0/8" -Action Allow

# PowerShell Remoting für VPN-Subnetz
New-NetFirewallRule -DisplayName "WinRM from VPN" -Direction Inbound -Protocol TCP -LocalPort 5985,5986 -RemoteAddress "10.0.0.0/8,172.16.0.0/12,10.0.0.0/8" -Action Allow

# RDP als Fallback (optional)
New-NetFirewallRule -DisplayName "RDP from VPN" -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress "10.0.0.0/8,172.16.0.0/12,10.0.0.0/8" -Action Allow
```

### **SSH-Hardening**
```powershell
# sshd_config Sicherheitseinstellungen
# C:\ProgramData\ssh\sshd_config

# Empfohlene Konfiguration:
Protocol 2
PermitRootLogin no
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 60
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
IgnoreRhosts yes
HostbasedAuthentication no
X11Forwarding no
AllowUsers dbadmin
```

## 🤖 PowerShell Remoting Setup

### **WinRM Konfiguration für Remote-Management**
```powershell
# Auf Windows PC: WinRM aktivieren
Enable-PSRemoting -Force

# TrustedHosts für VPN-Clients (optional)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*.corp.local"

# HTTPS für sichere Verbindung (optional)
New-SelfSignedCertificate -DnsName "windows-pc.corp.local" -CertStoreLocation Cert:\LocalMachine\My
```

### **Remote-PowerShell vom Mac**
```bash
# Via SSH + PowerShell
ssh windows-pc "powershell.exe -Command 'Get-Service | Where-Object Status -eq Running'"

# Oder mit pwsh (falls auf Mac installiert)
pwsh -Command "Enter-PSSession -ComputerName windows-pc.corp.local -Credential (Get-Credential)"
```

## 📊 Verbindungsmonitoring

### **Connectivity Health-Checks**
```bash
# Mac-Script für Verbindungs-Status
cat > ~/Scripts/check-infrastructure.sh << 'EOF'
#!/bin/bash

echo "=== Infrastructure Connectivity Check ==="
echo "Date: $(date)"
echo

# VPN Status
echo "🌐 VPN Status:"
ifconfig | grep -q "utun" && echo "✅ VPN Connected" || echo "❌ VPN Disconnected"
echo

# Windows PC SSH
echo "🖥️ Windows PC SSH:"
ssh -o ConnectTimeout=5 -o BatchMode=yes windows-pc "echo '✅ SSH OK'" 2>/dev/null || echo "❌ SSH Failed"

# Ubuntu VM via Jump
echo "🐧 Ubuntu VM SSH:"
ssh -o ConnectTimeout=5 -o BatchMode=yes ubuntu-vm "echo '✅ VM SSH OK'" 2>/dev/null || echo "❌ VM SSH Failed"

# Pi 5 Direct
echo "🥧 Pi 5 SSH:"
ssh -o ConnectTimeout=5 -o BatchMode=yes pi5 "echo '✅ Pi5 SSH OK'" 2>/dev/null || echo "❌ Pi5 SSH Failed"

echo
echo "=== End Check ==="
EOF

chmod +x ~/Scripts/check-infrastructure.sh

# Cron-Job für regelmäßige Checks (optional)
echo "*/15 * * * * ~/Scripts/check-infrastructure.sh >> ~/Logs/infrastructure.log 2>&1" | crontab -
```

### **Performance-Monitoring**
```bash
# Latency-Tests
ping -c 3 windows-pc.corp.local

# SSH-Verbindungszeit messen
time ssh windows-pc "exit"

# Throughput-Test über SSH
ssh windows-pc "powershell.exe -Command 'Get-Random -Count 1000'" | wc -l
```

## 🚀 Automatisierte Deployment-Scripts

### **Remote-Setup-Script**
```bash
# deploy-ssh-setup.sh - Automatisiertes SSH-Setup
cat > ~/Scripts/deploy-ssh-setup.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Deploying SSH Setup to Windows PC..."

# SSH-Key kopieren (falls noch nicht geschehen)
if ! ssh -o BatchMode=yes windows-pc "exit" 2>/dev/null; then
    echo "📋 Copying SSH key..."
    ssh-copy-id -i ~/.ssh/id_ed25519_firma.pub dbadmin@windows-pc.corp.local
fi

# SSH-Config testen
echo "🔍 Testing SSH configuration..."
ssh windows-pc "powershell.exe -Command 'Write-Host SSH Setup Complete'"

# Ubuntu VM Zugriff via Jump testen
echo "🐧 Testing Ubuntu VM access..."
ssh ubuntu-vm "hostname && uptime"

echo "✅ SSH Setup deployment complete!"
EOF

chmod +x ~/Scripts/deploy-ssh-setup.sh
```

## 📋 Troubleshooting

### **Häufige Probleme**

#### **SSH-Verbindung schlägt fehl**
```bash
# Debug-Modus für SSH
ssh -vvv windows-pc

# SSH-Agent Status prüfen
ssh-add -l

# DNS-Resolution testen
nslookup windows-pc.corp.local
```

#### **PowerShell Remoting Probleme**
```powershell
# Auf Windows PC: WinRM Status prüfen
Get-Service WinRM
Test-WSMan

# Firewall-Regeln prüfen
Get-NetFirewallRule -DisplayName "*WinRM*" | Format-Table
```

#### **VPN-Verbindungsprobleme**
```bash
# Route-Tabelle nach VPN-Verbindung prüfen
netstat -rn

# DNS-Server nach VPN prüfen
scutil --dns

# VPN-Interface Status
ifconfig utun0
```

### **Fallback-Lösungen**
- **SSH fehlgeschlagen:** Remote Desktop via Windows App als Backup
- **VPN instabil:** Direct SSH über öffentliche IP (falls verfügbar)
- **PowerShell Remoting:** SSH + PowerShell.exe als Alternative

## 🔗 Related Documents


---

**Status:** Setup-Phase  
**Nächste Schritte:** OpenSSH Server auf Windows PC aktivieren, SSH-Keys verteilen, VPN-Verbindung testen