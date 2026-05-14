# PostgreSQL Migration - Technische Anleitung

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → PostgreSQL Migration
> **Zweck**: Step-by-Step Schema-Conversion, Datentyp-Mapping, View-Migration

## Automated Schema Conversion

### Data Type Mapping Automation
```bash
# Automatische Datentyp-Konvertierung
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
-- SQL Server → PostgreSQL Mapping
-- VARCHAR(n) → VARCHAR(n) (gleich)
-- NVARCHAR(n) → TEXT (PostgreSQL nutzt UTF-8)
-- DATETIME → TIMESTAMP
-- INT → INTEGER
-- DECIMAL(p,s) → NUMERIC(p,s)
-- MONEY → NUMERIC(19,4)
-- BIT → BOOLEAN
-- UNIQUEIDENTIFIER → UUID
\""
```

### Schema Conversion Script
```bash
# Vollautomatisierte Schema-Migration
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
-- 1. Create Target Schema
CREATE SCHEMA IF NOT EXISTS order_processing;

-- 2. Set Search Path
SET search_path TO order_processing, public;

-- 3. Create Tables with PostgreSQL Types
CREATE TABLE IF NOT EXISTS order_doc (
    order_id BIGINT PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL,
    erstellt_am TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date DATE,
    net_amount NUMERIC(10,2),
    is_aktiv BOOLEAN DEFAULT true,
    site_id INTEGER,
    customer_id BIGINT
);

-- 4. Create Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_order_erstellt_am ON order_doc(erstellt_am);
CREATE INDEX IF NOT EXISTS idx_order_expiry ON order_doc(expiry_date);
\""
```

## View Dependencies Resolution

### Level 1: Basis-Dimensions
```bash
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
CREATE OR REPLACE VIEW vw_dim_customer AS
SELECT customer_id, customer_code, segment_id, created_at
FROM customer;
\""
```

### Level 2: Fact Tables
```bash
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
CREATE OR REPLACE VIEW vw_fact_order AS
SELECT r.*, p.customer_code as customer_label
FROM order_doc r
JOIN vw_dim_customer p ON r.customer_id = p.customer_id;
\""
```

### Level 3: KPI Views
```bash
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
CREATE OR REPLACE VIEW vw_kpi_order_intake AS
SELECT
    DATE(erstellt_am) as datum,
    COUNT(*) as count_orders,
    SUM(net_amount) as gesamtwert
FROM vw_fact_order
GROUP BY DATE(erstellt_am);
\""
```

## Daily Sync Mechanism

### Master Sync Script
```bash
#!/bin/bash
# daily_sync_master.sh - Runs at 2:00 MEZ via cron

SCRIPT_DIR="/opt/postgresql_sync"
LOG_DIR="/var/log/postgresql_sync"
LOG_FILE="$LOG_DIR/sync_$(date +%Y%m%d_%H%M%S).log"

# Main sync process
main() {
    log "=== Starting daily sync from SQL Server to PostgreSQL ==="

    # Step 1: Export from SQL Server
    "$SCRIPT_DIR/01_export_sqlserver.sh"

    # Step 2: Transform data
    "$SCRIPT_DIR/02_transform_data.sh"

    # Step 3: Import to PostgreSQL
    "$SCRIPT_DIR/03_import_postgresql.sh"

    # Step 4: Update materialized views
    "$SCRIPT_DIR/04_refresh_materialized.sh"

    # Step 5: Validate sync
    "$SCRIPT_DIR/05_validate_sync.sh"

    log "=== Sync completed successfully ==="
}
```

## Migration Validation

### Data Validation
```bash
# Automated validation
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
SELECT * FROM validate_migration();
\""
```

---
**Siehe auch**:
- [PostgreSQL Referenz](../reference/POSTGRESQL_REFERENZ.md) - Technische Details
- [PostgreSQL Daily Ops](../how-to/POSTGRESQL_DAILY_OPS.md) - Tägliche Operationen
- [PostgreSQL Migration Guide](POSTGRESQL_MIGRATION_GUIDE.md) - 3-Wochen-Plan
