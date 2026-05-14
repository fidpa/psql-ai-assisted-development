# Migration Assessment

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Migration Assessment
> **Zweck**: SQL Server Inventarisierung, Schema-Analyse, Data Volume

## SQL Server Inventarisierung

```powershell
# Remote-Ausführung vom Mac via SSH
ssh windows-pc "powershell.exe -Command '
Get-Service -Name \"SQL*\" | Select-Object Name, Status, StartType

# Datenbank-Liste
sqlcmd -S localhost -E -Q \"SELECT name, database_id, create_date FROM sys.databases\"
'"
```

## Schema-Analyse

### Data Volume Assessment
```sql
-- Datenbank-Größen ermitteln
SELECT
    DB_NAME(database_id) AS DatabaseName,
    CAST(SUM(size) * 8.0 / 1024 / 1024 AS DECIMAL(10,2)) AS SizeGB
FROM sys.master_files
WHERE type = 0
GROUP BY database_id
ORDER BY SizeGB DESC;
```

## Data Quality Checks

### Row Count Validation
```sql
-- SQL Server
SELECT
    name as table_name,
    SUM(rows) as row_count
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
GROUP BY name;

-- PostgreSQL
SELECT
    tablename,
    n_tup_ins as row_count
FROM pg_stat_user_tables;
```

---
**Siehe auch**:
- [Migration Strategie](../explanation/MIGRATION_STRATEGIE.md) - Warum PostgreSQL
- [PostgreSQL Migration Guide](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md) - Timeline
