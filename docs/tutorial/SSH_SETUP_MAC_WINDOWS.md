# SSH-Setup Replikations-Anleitung - Erfolgreich getestet

*Erstellt am: 2025-07-14*  
*Status: ✅ Funktionsfähig getestet*

## 🎯 Erfolgreiche Konfiguration

**Verbindung hergestellt:** Mac → VPN (203.0.113.45) → Windows PC (10.0.0.10)  
**SSH-Verbindung:** `ssh tunnel-host` → `dbadmin@legacy-mssql-host C:\Users\dbadmin@legacy-mssql-host>`

## 📋 Komplette Replikations-Anleitung

### **Voraussetzungen:**
- VPN-Verbindung zu 203.0.113.45 aktiv
- Administrator-Rechte auf Windows PC
- Appointmental/PowerShell-Zugriff

---

## **Phase 1: Windows PC SSH-Server Setup**

### **1.1 PowerShell als Administrator starten:**
```
Windows-Taste → "PowerShell" → Rechtsklick → "Als Administrator ausführen"
```

### **1.2 OpenSSH Server installieren:**
```powershell
# OpenSSH Server Feature installieren
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# SSH Server Service aktivieren
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Firewall-Regel für SSH erstellen
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

### **1.3 Windows PC IP-Adresse ermitteln:**
```powershell
ipconfig | findstr "IPv4"
```
**Erwartete Ausgabe (Beispiel):**
```
   IPv4-Adresse  . . . . . . . . . . : 10.0.0.10
   IPv4-Adresse  . . . . . . . . . . : 10.0.0.1
   IPv4-Adresse  . . . . . . . . . . : 10.0.0.2
```
**→ Notiere die erste IP (10.0.0.10 = Haupt-Netzwerk-IP)**

---

## **Phase 2: Mac SSH-Key Generierung**

### **2.1 SSH-Key erstellen:**
```bash
# Ed25519 Key generieren (ersetze [HOSTNAME] mit tatsächlichem Namen)
ssh-keygen -t ed25519 -C "dbadmin@legacy-host" -f ~/.ssh/id_ed25519_arni

# Bei Prompts: ENTER drücken (kein Passwort)
```

### **2.2 Public Key anzeigen:**
```bash
cat ~/.ssh/id_ed25519_arni.pub
```
**Erwartete Ausgabe (Beispiel):**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA<REDACTED-PUBLIC-KEY> dbadmin@legacy-host
```
**→ Komplette Zeile kopieren für nächsten Schritt**

---

## **Phase 3: SSH-Key zu Windows übertragen**

### **3.1 SSH-Verzeichnis auf Windows erstellen:**
```powershell
# In normaler PowerShell (nicht Administrator)
mkdir C:\Users\dbadmin\.ssh
```

### **3.2 Public Key hinzufügen:**
```powershell
# Public Key in authorized_keys einfügen (ersetze [PUBLIC-KEY] mit kopiertem Inhalt)
echo "[PUBLIC-KEY-KOMPLETT]" >> C:\Users\dbadmin\.ssh\authorized_keys

# Beispiel mit echtem Key:
# echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA<REDACTED-PUBLIC-KEY> dbadmin@legacy-host" >> C:\Users\dbadmin\.ssh\authorized_keys
```

### **3.3 Authorized Keys prüfen:**
```powershell
Get-Content C:\Users\dbadmin\.ssh\authorized_keys
```

---

## **Phase 4: Mac SSH-Client Konfiguration**

### **4.1 SSH-Config erstellen/reparieren:**
```bash
# Eventuelle defekte Config entfernen
rm ~/.ssh/config

# Neue SSH-Config erstellen (ersetze [WINDOWS-IP] mit ermittelter IP)
cat > ~/.ssh/config << 'EOF'
Host tunnel-host
    HostName 10.0.0.10
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_arni
    Port 22
    ForwardAgent yes
    ServerAliveInterval 60
EOF
```

### **4.2 SSH-Config validieren:**
```bash
cat ~/.ssh/config
```

### **4.3 SSH-Key zum Agent hinzufügen:**
```bash
# SSH-Agent starten
eval "$(ssh-agent -s)"

# Key hinzufügen
ssh-add ~/.ssh/id_ed25519_arni

# Geladene Keys prüfen
ssh-add -l
```

---

## **Phase 5: SSH-Verbindung testen**

### **5.1 Erste SSH-Verbindung:**
```bash
ssh tunnel-host
```

### **5.2 Bei erster Verbindung:**
```
The authenticity of host '10.0.0.10 (10.0.0.10)' can't be established.
...
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```
**→ "yes" eingeben und ENTER**

### **5.3 Erfolgreiche Verbindung:**
```
dbadmin@legacy-mssql-host C:\Users\dbadmin@legacy-mssql-host>
```
**→ SSH-Setup erfolgreich! 🎉**

---

## **Troubleshooting-Checkliste**

### **SSH-Verbindung schlägt fehl:**
```bash
# Verbose SSH für Debugging
ssh -v tunnel-host

# Direkter IP-Test
ssh dbadmin@10.0.0.10
```

### **Windows SSH-Service prüfen:**
```powershell
# Service Status
Get-Service sshd

# SSH Server Logs
Get-WinEvent -LogName "OpenSSH/Operational" | Select-Object -First 5
```

### **MAC SSH-Key Probleme:**
```bash
# SSH-Agent Status
ssh-add -l

# Key neu laden
ssh-add ~/.ssh/id_ed25519_arni
```

---

## **Validierung der Installation**

### **Erfolgs-Kriterien:**
- [ ] OpenSSH Server läuft auf Windows: `Get-Service sshd` → Status "Running"
- [ ] SSH-Key auf Mac generiert: `ls ~/.ssh/id_ed25519_arni*` → 2 Dateien
- [ ] Public Key auf Windows: `Get-Content C:\Users\dbadmin\.ssh\authorized_keys` → Key sichtbar
- [ ] SSH-Config auf Mac: `cat ~/.ssh/config` → Host-Eintrag vorhanden
- [ ] SSH-Verbindung: `ssh tunnel-host` → Windows PowerShell prompt

### **Performance-Test:**
```bash
# Verbindungszeit messen
time ssh tunnel-host "exit"

# Remote-Befehl testen
ssh tunnel-host "powershell.exe -Command 'Get-ComputerInfo | Select-Object WindowsProductName'"
```

---

## **Backup der Konfiguration**

### **SSH-Keys sichern (Mac):**
```bash
# SSH-Keys backup
cp -r ~/.ssh ~/Backup/ssh-backup-$(date +%Y%m%d)

# Oder spezifisch für dieses Setup
cp ~/.ssh/id_ed25519_arni* ~/Backup/
cp ~/.ssh/config ~/Backup/ssh-config-$(date +%Y%m%d)
```

### **Windows SSH-Config sichern:**
```powershell
# SSH-Konfiguration backup
Copy-Item C:\Users\dbadmin\.ssh\authorized_keys C:\Users\dbadmin\Documents\authorized_keys_backup.txt
```

---

## **Erweiterte Konfiguration (Optional)**

### **SSH-Tunnel für Databases:**
```bash
# PostgreSQL Tunnel (Ubuntu VM)
ssh -L 5433:10.0.0.30:5432 tunnel-host -N

# SQL Server Tunnel
ssh -L 1434:localhost:1433 tunnel-host -N
```

### **PowerShell Remoting aktivieren:**
```powershell
# Auf Windows PC für erweiterte Remote-Verwaltung
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*"
```

---

## **Replikation auf anderen Geräten**

### **Neue SSH-Keys für andere Macs:**
```bash
# Anderen Key-Namen verwenden
ssh-keygen -t ed25519 -C "dbadmin@[andere-device]" -f ~/.ssh/id_ed25519_arni_[device]

# Zusätzlichen Public Key zu Windows hinzufügen
ssh tunnel-host "echo '[NEW-PUBLIC-KEY]' >> C:\Users\dbadmin\.ssh\authorized_keys"
```

### **SSH-Config für Multiple Devices:**
```bash
# SSH-Config erweitern
cat >> ~/.ssh/config << 'EOF'
Host tunnel-host-backup
    HostName 10.0.0.10
    User dbadmin
    IdentityFile ~/.ssh/id_ed25519_arni_backup
    Port 22
EOF
```

---

**Status:** ✅ Produktiv einsatzbereit  
**Getestet am:** 2025-07-14  
**VPN:** 203.0.113.45  
**Windows PC:** 10.0.0.10 (legacy-mssql-host)  
**SSH-Config:** tunnel-host