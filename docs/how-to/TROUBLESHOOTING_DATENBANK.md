# Troubleshooting Datenbank

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Troubleshooting
> **Zweck**: Performance-Patterns, Query-Optimization, FAQ

## Query-Optimization Patterns

### Anti-Pattern: Korrelierte Subqueries
```sql
-- ❌ LANGSAM: Korrelierte Subquery
SELECT
    b.ProviderID,
    b.Name,
    (SELECT COUNT(*) FROM Order r
     WHERE r.ProviderID = b.ProviderID) as OrderCount
FROM Provider b;

-- ✅ SCHNELL: JOIN mit Aggregation
SELECT
    b.ProviderID,
    b.Name,
    COALESCE(r.OrderCount, 0) as OrderCount
FROM Provider b
LEFT JOIN (
    SELECT ProviderID, COUNT(*) as OrderCount
    FROM Order
    GROUP BY ProviderID
) r ON b.ProviderID = r.ProviderID;
```

### Pattern: Conditional Aggregation
```sql
SELECT
    ProviderID,
    COUNT(*) as Total,
    COUNT(CASE WHEN ScanDatum IS NULL THEN 1 END) as NichtGescans,
    COUNT(CASE WHEN CaptureDatum IS NULL THEN 1 END) as NichtErfasst
FROM Order
WHERE Deleted = 0
GROUP BY ProviderID;
```

## Performance-Troubleshooting

### Query Plan Cache-Analyse
```sql
-- Top 10 CPU-intensive Queries
SELECT TOP 10
    qs.total_worker_time/1000 AS CPU_MS,
    qs.execution_count,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2) + 1) AS QueryText
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY qs.total_worker_time DESC;
```

## Häufige Probleme

### Problem: "Arithmetic overflow error converting money to data type numeric"
```sql
-- Lösung: Explizite Konvertierung mit größerem Bereich
CAST(MoneyColumn AS DECIMAL(19,4))
```

### Problem: Power BI DirectQuery Timeout
```sql
-- Lösung: Aggregation Pushdown
CREATE VIEW vw_PowerBI_PreGrouped AS
SELECT
    CAST(DateColumn AS DATE) as Date,
    CategoryID,
    COUNT(*) as RecordCount,
    SUM(Amount) as TotalAmount
FROM LargeTable
GROUP BY CAST(DateColumn AS DATE), CategoryID;
```

---
**Siehe auch**:
- [SQL Server Legacy](../reference/SQL_SERVER_LEGACY.md) - Express Limits
- [PostgreSQL Daily Ops](POSTGRESQL_DAILY_OPS.md) - PostgreSQL Troubleshooting
