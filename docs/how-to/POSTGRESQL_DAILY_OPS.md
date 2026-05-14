@./docs/templates/PSQL_CORE.md
@./docs/templates/PSQL_ERRORS.md  
@./docs/templates/PSQL_PATTERNS.md
@./docs/templates/PSQL_DAILY.md

# PSQL.md - PostgreSQL KI-Assistant Command Center

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → PSQL.md | **Status**: Optimiert für Claude Code  
> **Zweck**: Sofort ausführbare PostgreSQL-Operationen für KI-Assistenten

## ⚡ INSTANT COMMANDS - COPY & PASTE READY

### 🔑 Standard Connection (Verwende für ALLE Operationen)
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SQL_HIER\""
```

## 🎯 TÄGLICHE OPERATIONEN

### Health Check (30 Sekunden)
```bash
# 1. Connection Count
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT count(*) as connections FROM pg_stat_activity;\""

# 2. Database Size
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT pg_size_pretty(pg_database_size('postgres')) as db_size;\""

# 3. Slow Queries Check
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT query, query_start FROM pg_stat_activity WHERE state = 'active' AND query_start < CURRENT_TIMESTAMP - INTERVAL '5 minutes';\""
```

### Comprehensive Health Check (Automated)
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM daily_health_check();\""
```

## 🚨 CRITICAL ERROR RESPONSES

### Bei Fehlercodes (SOFORT-AKTIONEN)
- **40001** (Deadlock): `SELECT retry_with_backoff('YOUR_OPERATION', 3, 1000);`
- **53300** (Too many connections): `SELECT emergency_response('CONNECTION_LIMIT');`
- **08006** (Connection failure): `SELECT * FROM check_connection_health();`
- **42P01** (Table missing): Prüfe Schema-Migration in [PSQL_TEMPLATE.md](../reference/POSTGRESQL_REFERENZ.md)

### Emergency Response Commands
```bash
# Connection Limit Reached
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT emergency_response('CONNECTION_LIMIT');\""

# High CPU Usage
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT emergency_response('HIGH_CPU');\""

# Disk Full
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT emergency_response('DISK_FULL');\""
```

## 🏗️ STANDARD VIEW PATTERNS

### KPI View (Standard Pattern)
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
CREATE OR REPLACE VIEW vw_KPI_[NAME] AS
SELECT 
    [DATUM] as datum,
    [KENNZAHL] as kpi_wert,
    [KATEGORIE] as kategorie
FROM [BASIS_VIEW]
WHERE [FILTER_BEDINGUNG];
\""
```

### Power BI Optimized View
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
CREATE OR REPLACE VIEW vw_PowerBI_[NAME] AS
SELECT 
    datum::date as [Datum],
    kpi_wert::numeric(10,2) as [KPI_Wert],
    kategorie::varchar(50) as [Kategorie]
FROM vw_KPI_[NAME]
WHERE datum >= CURRENT_DATE - INTERVAL '365 days';
\""
```

## 🔄 MIGRATION QUICK-COMMANDS

### Schema Setup
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"CREATE SCHEMA IF NOT EXISTS order_processing; SET search_path TO order_processing, public;\""
```

### Migration Validation
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM validate_migration();\""
```

### Performance Benchmark
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM benchmark_critical_queries();\""
```

## 🔙 ROLLBACK PROCEDURES

### Emergency Rollback (<60 Sekunden)
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
DO \$\$
DECLARE backup_schema TEXT;
BEGIN
    SELECT schemaname INTO backup_schema FROM information_schema.schemata 
    WHERE schemaname LIKE 'backup_%' ORDER BY schemaname DESC LIMIT 1;
    EXECUTE format('DROP SCHEMA IF EXISTS order_processing CASCADE');
    EXECUTE format('ALTER SCHEMA %I RENAME TO order_processing', backup_schema);
END \$\$;
\""
```

### Create Recovery Point
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT create_recovery_point('before_operation_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MI'));\""
```

## 📦 BACKUP QUICK-COMMANDS

### Schema Backup
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\pg_dump.exe' -h localhost -p 5432 -U postgres --schema-only postgres > C:\\backup\\schema_$(date +%Y%m%d_%H%M%S).sql"
```

### Complete Backup
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\pg_dump.exe' -h localhost -p 5432 -U postgres -Fc postgres > C:\\backup\\complete_$(date +%Y%m%d_%H%M%S).backup"
```

## 📊 PERFORMANCE OPTIMIZATION

### Intelligent VACUUM
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT intelligent_vacuum();\""
```

### Partition Maintenance
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT maintain_partitions();\""
```

### Performance Settings Check
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM verify_performance_settings();\""
```

## 🔗 DETAILLIERTE REFERENZEN

**Für komplexe Operationen siehe:**
- **[PSQL_TEMPLATE.md](../reference/POSTGRESQL_REFERENZ.md)**: Vollständige Funktions-Definitionen
- **[MIGRATION.md](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md)**: 3-Wochen Migrations-Timeline  

**Template-Referenzen:**
- **[templates/PSQL_CORE.md](../reference/templates/PSQL_CORE.md)**: Kern-Befehle
- **[templates/PSQL_ERRORS.md](../reference/templates/PSQL_ERRORS.md)**: Error Handling
- **[templates/PSQL_PATTERNS.md](../reference/templates/PSQL_PATTERNS.md)**: SQL Patterns

---
**📚 NAVIGATION**:
- **🏠 Master**: [CLAUDE.md](../../CLAUDE.md) - KI-Assistent Direktiven
- **🔧 Kompakt**: PSQL.md (diese Datei) - Sofort ausführbare Befehle
- **📖 Vollständig**: [PSQL_TEMPLATE.md](../reference/POSTGRESQL_REFERENZ.md) - Detaillierte Implementierungen
- **🚀 Migration**: [MIGRATION.md](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md) - Projekt-Timeline
- **🏗️ System**: [PROJECT.md](../explanation/PROJEKT_ARCHITEKTUR.md) - Geschäftslogik

---
*Optimiert für Claude Code Memory Management | Zeilen: ~250*  
*Vollständige Details in PSQL_TEMPLATE.md | Zeilen: 2300+*  
*Letzte Aktualisierung: 2025-07-10*