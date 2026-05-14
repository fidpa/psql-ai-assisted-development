# Power BI Dashboard-Entwicklung

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Power BI Development
> **Zweck**: Visual Design, Deployment-Checklist, DirectQuery Optimization

## DirectQuery Optimization

### Query-Folding Best Practices
```sql
-- ✅ OPTIMAL: Nutze optimierte Views
SELECT * FROM vw_PowerBI_Dashboard_Live;

-- PostgreSQL View-Optimierung
CREATE VIEW vw_PowerBI_Dashboard_Live AS
SELECT
    kpi_a_last_working_day,
    FORMAT(kpi_a_last_working_day, '#,##0') AS E1_Formatiert,
    CASE
        WHEN S3_Gesamt > 1000 THEN 'Kritisch'
        WHEN S3_Gesamt > 500 THEN 'Warnung'
        ELSE 'OK'
    END AS S3_Status
FROM vw_KPI_Dashboard_Gesamt;
```

### Connection-String Optimierung
```
// PostgreSQL
Server=localhost;
Port=5432;
Database=postgres;
UID=postgres;
PWD=${PGPASSWORD};
Timeout=30;
Command Timeout=60;
Application Name=PowerBI_KPI_Dashboard_PostgreSQL;
```

## Deployment Checklist

### Pre-Deployment
- [ ] Views deployed und getestet in PostgreSQL
- [ ] Connection String validiert
- [ ] Parameter-Konfiguration getestet
- [ ] DAX-Measures Performance-getestet
- [ ] Mobile-Responsiveness geprüft

### Post-Deployment
- [ ] DirectQuery Performance < 5 Sekunden
- [ ] Alle KPI-Cards laden korrekt
- [ ] Drill-Down Funktionen arbeiten
- [ ] Export-Funktionen verfügbar

## Testing-Strategien

### Automated Testing
```sql
-- KPI-Konsistenz Tests
SELECT
    CASE WHEN kpi_a_last_working_day BETWEEN 0 AND 10000 THEN 'PASS' ELSE 'FAIL' END AS E1_Test,
    CASE WHEN S3_Gesamt BETWEEN 0 AND 50000 THEN 'PASS' ELSE 'FAIL' END AS S3_Test
FROM vw_PowerBI_Dashboard_Live;
```

---
**Siehe auch**:
- [DAX Katalog](../reference/POWER_BI_DAX_KATALOG.md) - DAX Measures
- [PostgreSQL Daily Ops](POSTGRESQL_DAILY_OPS.md) - DirectQuery Performance
- [Projekt-Architektur](../explanation/PROJEKT_ARCHITEKTUR.md) - KPI-Definitionen
