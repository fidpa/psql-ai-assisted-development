# Mac PostgreSQL Tools - Referenz

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Mac PostgreSQL Tools
> **Zweck**: Tool-Vergleich, Installation, Features

## PostgreSQL GUI-Tools für Mac

### 1. pgAdmin 4 (Empfohlen)
```bash
# Installation
brew install --cask pgadmin4
```
**Features**:
- PostgreSQL-spezialisiert
- Schema-Visualisierung
- Query-Editor mit Autocomplete

### 2. DBeaver Community
```bash
# Installation
brew install --cask dbeaver-community
```
**Features**:
- Multi-Database (PostgreSQL, SQL Server, MySQL)
- Data Transfer zwischen DB-Typen
- ERD-Diagramme

### 3. Postico 2
```bash
# Installation
brew install --cask postico
```
**Features**:
- Mac-native UI
- Sehr intuitiv
- Kostenpflichtig

### 4. TablePlus
```bash
# Installation
brew install --cask tableplus
```
**Features**:
- Modern UI
- Multi-Database
- Schnell

### 5. psql (Command Line)
```bash
# Installation
brew install postgresql@15
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
```

## Tool-Vergleich

| Feature | pgAdmin | DBeaver | Postico | TablePlus |
|---------|---------|---------|---------|-----------|
| PostgreSQL | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| SQL Server | ❌ | ⭐⭐⭐⭐⭐ | ❌ | ⭐⭐⭐⭐ |
| Mac Native | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| SSH Tunnel | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Cost | Free | Free | Paid | Free/Paid |

### Empfehlung für Migration
1. **DBeaver** - SQL Server ↔ PostgreSQL Migration
2. **pgAdmin** - PostgreSQL-Administration
3. **Postico** - Tägliche Arbeit (Mac-like)

---
**Siehe auch**:
- [Mac PostgreSQL Verbindung](../how-to/MAC_POSTGRESQL_VERBINDUNG.md) - Setup
- [PostgreSQL Daily Ops](../how-to/POSTGRESQL_DAILY_OPS.md) - Workflows
