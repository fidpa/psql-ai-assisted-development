# PostgreSQL Referenz

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → PostgreSQL Referenz
> **Zweck**: Technische PostgreSQL-Referenz für Setup, Config, Datentypen, View-Hierarchie

## PostgreSQL Setup & Configuration

### Hardware-Optimierung für 64GB RAM

#### postgresql.conf Einstellungen
```bash
# Speicher-Optimierung (64GB System)
shared_buffers = 16GB              # 25% of RAM
effective_cache_size = 48GB        # 75% of RAM
work_mem = 256MB                   # Pro Operation
maintenance_work_mem = 2GB         # Für Maintenance
wal_buffers = 64MB                # Write-ahead logging
checkpoint_completion_target = 0.9

# CPU-Optimierung (16 Cores verfügbar)
max_parallel_workers_per_gather = 8
max_parallel_workers = 16
max_parallel_maintenance_workers = 4
parallel_leader_participation = on

# Connection-Pool
max_connections = 200
superuser_reserved_connections = 3

# Query-Planer
random_page_cost = 1.1            # SSD-optimiert
effective_io_concurrency = 200    # SSD-optimiert
default_statistics_target = 100   # Bessere Statistiken
```

### Security Setup

#### Dedicated Users & Permissions
```sql
-- KI-Assistant User Setup
CREATE USER claude_assistant WITH PASSWORD 'secure_password_here';
CREATE USER powerbi_user WITH PASSWORD 'powerbi_password_here';
CREATE USER sync_user WITH PASSWORD 'sync_password_here';

-- Database & Schema
CREATE DATABASE order_processing_pg OWNER claude_assistant;
\c order_processing_pg

-- Permissions
GRANT ALL PRIVILEGES ON DATABASE order_processing_pg TO claude_assistant;
GRANT CONNECT ON DATABASE order_processing_pg TO powerbi_user, sync_user;
GRANT USAGE ON SCHEMA public TO powerbi_user, sync_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO powerbi_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO sync_user;

-- Future objects
ALTER DEFAULT PRIVILEGES FOR USER claude_assistant IN SCHEMA public
GRANT SELECT ON TABLES TO powerbi_user;
ALTER DEFAULT PRIVILEGES FOR USER claude_assistant IN SCHEMA public
GRANT SELECT, INSERT, UPDATE ON TABLES TO sync_user;
```

## Data Type Mapping

### SQL Server → PostgreSQL Mapping
```sql
/*
SQL Server          PostgreSQL          Notes
-----------------   -----------------   ------------------------
DATETIME/DATETIME2  TIMESTAMP           Includes timezone
DATE                DATE                Direct mapping
MONEY               DECIMAL(19,4)       Explicit precision
BIT                 BOOLEAN             TRUE/FALSE
NVARCHAR(n)         VARCHAR(n)          UTF-8 default
VARCHAR(MAX)        TEXT                Unlimited length
UNIQUEIDENTIFIER    UUID                Direct mapping
IMAGE/VARBINARY     BYTEA               Binary data
*/

-- Example conversion function
CREATE OR REPLACE FUNCTION convert_money_to_decimal(money_value TEXT)
RETURNS DECIMAL(19,4) AS $$
BEGIN
    RETURN CAST(REPLACE(REPLACE(money_value, '$', ''), ',', '') AS DECIMAL(19,4));
END;
$$ LANGUAGE plpgsql;
```

## Table Partitioning Strategy

### Partitionierung für große Tabellen (65+ Mio. Rows)
```sql
-- Master table
CREATE TABLE appointment (
    appointment_id BIGSERIAL,
    order_line_id BIGINT NOT NULL,
    event_date DATE NOT NULL,
    service_date DATE,
    erstellt_am TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    geaendert_am TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_appointment PRIMARY KEY (appointment_id, event_date)
) PARTITION BY RANGE (event_date);

-- Create yearly partitions
DO $$
DECLARE
    year_start DATE;
    year_end DATE;
BEGIN
    FOR year IN 2020..2026 LOOP
        year_start := DATE (year || '-01-01');
        year_end := DATE ((year + 1) || '-01-01');

        EXECUTE format('
            CREATE TABLE appointment_%s PARTITION OF appointment
            FOR VALUES FROM (%L) TO (%L)',
            year, year_start, year_end
        );

        -- Create indexes on partition
        EXECUTE format('
            CREATE INDEX idx_appointment_%s_order_line
            ON appointment_%s (order_line_id)',
            year, year
        );
    END LOOP;
END $$;
```

## View Hierarchy & Dependencies

```
Level 1: Base Views (Dimensions & Facts)
├── vw_dim_provider
├── vw_dim_customer
├── vw_dim_working_days
├── vw_fact_order
└── vw_fact_order_intake

Level 2: Business Logic Views
├── vw_kpi_order_sorting
├── vw_kpi_capture_status
└── vw_kpi_expiry_basis

Level 3: Aggregation Views
├── vw_kpi_dashboard_e_werte
├── vw_kpi_dashboard_s_werte
├── vw_kpi_dashboard_d_werte
└── vw_kpi_dashboard_v_werte

Level 4: Final Dashboard Views
├── vw_kpi_dashboard_gesamt
└── vw_powerbi_dashboard_live
```

## Index Strategy

### Performance-kritische Indizes
```sql
-- 1. Covering Index für häufige Queries
CREATE INDEX idx_order_covering ON order_doc
(provider_id, erstellt_am, scan_date, capture_date)
INCLUDE (net_amount, order_number);

-- 2. Partial Indexes für gefilterte Queries
CREATE INDEX idx_order_uncaptured ON order_doc (provider_id, erstellt_am)
WHERE capture_date IS NULL AND deleted = FALSE;

-- 3. Expression Indexes
CREATE INDEX idx_order_month ON order_doc (DATE_TRUNC('month', erstellt_am));

-- 4. BRIN Indexes für große Tabellen
CREATE INDEX idx_appointment_date_brin ON appointment USING BRIN (event_date);
```

---
**Siehe auch**:
- [PostgreSQL Daily Ops](../how-to/POSTGRESQL_DAILY_OPS.md) - Tägliche Operationen
- [PostgreSQL Automation](../how-to/POSTGRESQL_AUTOMATION.md) - Emergency Response & KI-Integration
- [PostgreSQL Migration Guide](../tutorial/POSTGRESQL_MIGRATION_TECHNISCH.md) - Schema-Conversion
