# SQL Server Legacy - Referenz

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → SQL Server Legacy
> **Zweck**: SQL Server Express Limits, Bugs, Konstanten

## SQL Server Express Environment

### Technische Limitierungen
- **Datenbankgröße**: Maximum 10 GB pro Datenbank
- **Arbeitsspeicher**: Maximum 1 GB RAM (von 64 GB verfügbar!)
- **CPU**: Maximum 4 Cores
- **Buffer Pool**: Maximum 1410 MB
- **Version**: SQL Server 2022 Express Edition (16.0.1000.6)

### SQL Server 2022 Express Bugs

#### Gefilterte Indizes Bug
```sql
-- ❌ FEHLER in Express Edition mit BETWEEN
CREATE INDEX IX_Expiry_Filtered
ON dbo.Fact_Expiry_Mat (DaysUntilExpiry)
WHERE DaysUntilExpiry BETWEEN 0 AND 60;
-- Msg 156: Incorrect syntax near 'BETWEEN'

-- ✅ WORKAROUND: Explizite Vergleiche
CREATE INDEX IX_Expiry_Filtered
ON dbo.Fact_Expiry_Mat (DaysUntilExpiry)
WHERE DaysUntilExpiry >= 0
  AND DaysUntilExpiry <= 60;
```

#### Verschachtelte Aggregatfunktionen
```sql
-- ❌ FEHLER: Cannot perform aggregate on aggregate
SELECT STRING_AGG(
    Status + ':' + FORMAT(COUNT(*), '#,##0'), ', '
) FROM Order GROUP BY Status;

-- ✅ KORREKT: Mit CTE
WITH StatusCounts AS (
    SELECT Status, COUNT(*) AS Anzahl
    FROM Order
    GROUP BY Status
)
SELECT STRING_AGG(
    Status + ':' + FORMAT(Anzahl, '#,##0'), ', '
) WITHIN GROUP (ORDER BY Status)
FROM StatusCounts;
```

## Projekt-spezifische Konstanten

### ProviderGroupIDs
```sql
DECLARE @SENTINEL INT = 3;          -- SENTINEL Hauptgruppe
DECLARE @TIER_B INT = 14;   -- Partner tier B (external)
```

### ServiceTypeIDs
```sql
-- Diese werden NICHT manual sortiert
(1, 'Category10'),
(5, 'Category20'),
(17, 'Category30'),
(18, 'Category40')
```

### ImportType Definitionen
```sql
(6, 'Channel_C', 1),     -- Inbound electronic channel
(7, 'Channel_D', 1)      -- Inbound electronic channel
```

### InvoiceInsurer Status-Codes
```sql
DECLARE @STATUS_NEU INT = 1;        -- Unbestätigt (C1/C2)
DECLARE @STATUS_BESTAETIGT INT = 2; -- Bestätigt
DECLARE @STATUS_BEZAHLT INT = 3;    -- Bezahlt
```

---
**Siehe auch**:
- [Troubleshooting Datenbank](../how-to/TROUBLESHOOTING_DATENBANK.md) - Performance-Patterns
- [PostgreSQL Referenz](POSTGRESQL_REFERENZ.md) - Migrierte Umgebung
