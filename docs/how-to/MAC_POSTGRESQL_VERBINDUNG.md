# Mac PostgreSQL Verbindung

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Mac PostgreSQL Verbindung
> **Zweck**: VPN Setup, SSH-Tunnel, Remote DB Connection

## VPN-Konfiguration

### VPN-Details
- **VPN-Gateway**: 203.0.113.45
- **Windows PC**: [interne IP nach VPN]
- **Ubuntu VM**: 10.0.0.30

### VPN-Verbindung testen
```bash
# VPN-Status prüfen
ifconfig | grep -A 5 "utun"

# Windows PC ping
ping [windows-pc-internal-ip]
```

## SSH-Tunnel Setup

### SSH-Tunnel für PostgreSQL
```bash
# SSH-Tunnel (Local Port 5433 → Ubuntu VM Port 5432)
ssh -L 5433:10.0.0.30:5432 dbadmin@[windows-pc-ip] -N

# SSH Config
cat >> ~/.ssh/config << 'EOF'
Host postgres-tunnel
    HostName [windows-pc-ip]
    User dbadmin
    LocalForward 5433 10.0.0.30:5432
    IdentityFile ~/.ssh/id_ed25519_firma
EOF

# Tunnel starten
ssh postgres-tunnel -N
```

## Database Connection

### pgAdmin Server Setup
```json
{
  "Name": "Ubuntu VM PostgreSQL",
  "Host": "localhost",
  "Port": 5433,
  "Database": "postgres",
  "Username": "dashboard",
  "SSL Mode": "prefer"
}
```

### DBeaver Connection
```bash
# SSH Tunnel in DBeaver
# SSH Host: [windows-pc-ip]
# SSH Port: 22
# Private Key: ~/.ssh/id_ed25519_firma
```

## Automated Tunnel Management

### Start Tunnels
```bash
# ~/Scripts/start-db-tunnels.sh
ssh -f -N -L 5433:10.0.0.30:5432 windows-corp
echo "✅ PostgreSQL Tunnel: localhost:5433"
```

### Stop Tunnels
```bash
# ~/Scripts/stop-db-tunnels.sh
pkill -f "ssh.*-L.*windows-corp"
```

---
**Siehe auch**:
- [Mac PostgreSQL Tools](../reference/MAC_POSTGRESQL_TOOLS.md) - Tool-Vergleich
- [VPN SSH Setup](VPN_SSH_KONFIGURATION.md) - Detaillierte Konfiguration
