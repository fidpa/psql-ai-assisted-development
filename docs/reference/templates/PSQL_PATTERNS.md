# PostgreSQL SQL Patterns - Template

## 🏗️ View Creation Patterns

### Standard KPI View
```sql
CREATE OR REPLACE VIEW vw_KPI_[NAME] AS
SELECT 
    [DATUM] as datum,
    [KENNZAHL] as kpi_wert,
    [KATEGORIE] as kategorie
FROM [BASIS_VIEW]
WHERE [FILTER_BEDINGUNG];
```

### Materialized View Pattern
```sql
CREATE MATERIALIZED VIEW vw_Fact_[NAME]_Mat AS
SELECT [AGGREGATION_QUERY];
CREATE INDEX idx_[NAME]_date ON vw_Fact_[NAME]_Mat(datum);
```

### Power BI Optimized View
```sql
CREATE OR REPLACE VIEW vw_PowerBI_[NAME] AS
SELECT 
    datum::date as [Datum],
    kpi_wert::numeric(10,2) as [KPI_Wert],
    kategorie::varchar(50) as [Kategorie]
FROM vw_KPI_[NAME]
WHERE datum >= CURRENT_DATE - INTERVAL '365 days';
```

## 📊 Data Type Mapping

### SQL Server → PostgreSQL
- VARCHAR(n) → VARCHAR(n)
- NVARCHAR(n) → TEXT
- DATETIME → TIMESTAMP
- INT → INTEGER
- DECIMAL(p,s) → NUMERIC(p,s)
- BIT → BOOLEAN
- UNIQUEIDENTIFIER → UUID

## 🎯 Project-Specific Patterns

### Expiry calculation
```sql
CREATE OR REPLACE VIEW vw_Fact_Expiry AS
SELECT 
    order_id,
    expiry_date,
    CASE 
        WHEN expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'KRITISCH'
        WHEN expiry_date <= CURRENT_DATE + INTERVAL '60 days' THEN 'WARNUNG'
        ELSE 'OK'
    END as expiry_status
FROM dim_order
WHERE expiry_date IS NOT NULL;
```