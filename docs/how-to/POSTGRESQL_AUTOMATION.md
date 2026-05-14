# PostgreSQL Automation & Emergency Response

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → PostgreSQL Automation
> **Zweck**: Daily Sync, Emergency Procedures, KI-Assistant Integration

## Daily Health Check

```bash
# Automated Health Check (5 Minuten)
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
-- Comprehensive Daily Health Check
CREATE OR REPLACE FUNCTION daily_health_check()
RETURNS TABLE(
    check_category TEXT,
    check_name TEXT,
    status TEXT,
    details TEXT,
    action_required TEXT
) AS \$\$
BEGIN
    -- 1. Connection Health
    -- 2. Performance Metrics
    -- 3. System Alerts
    -- 4. Backup Verification
    -- 5. Partition Maintenance
    RETURN QUERY SELECT * FROM temp_health_results;
END
\$\$ LANGUAGE plpgsql;

-- Usage: SELECT * FROM daily_health_check();
\""
```

## Emergency Response Procedures

```bash
# Emergency Response Function
powershell.exe "$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"
CREATE OR REPLACE FUNCTION emergency_response(incident_type TEXT)
RETURNS TEXT AS \$\$
BEGIN
    CASE incident_type
        WHEN 'HIGH_CPU' THEN
            -- Kill long-running queries
            PERFORM pg_cancel_backend(pid)
            FROM pg_stat_activity
            WHERE state = 'active'
            AND query_start < CURRENT_TIMESTAMP - INTERVAL '10 minutes';
            RETURN 'Long-running queries terminated';

        WHEN 'DISK_FULL' THEN
            -- Emergency cleanup
            PERFORM intelligent_vacuum();
            RETURN 'Emergency VACUUM completed';

        WHEN 'CONNECTION_LIMIT' THEN
            -- Kill idle connections
            PERFORM pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE state = 'idle'
            AND state_change < CURRENT_TIMESTAMP - INTERVAL '1 hour';
            RETURN 'Idle connections terminated';

        ELSE
            RETURN 'Unknown incident type: ' || incident_type;
    END CASE;
END
\$\$ LANGUAGE plpgsql;
\""
```

## Master Automation Controller

```bash
#!/bin/bash
# master_automation.sh - Central automation script

OPERATION=$1
ENVIRONMENT=${2:-production}

case "$OPERATION" in
    "sync")
        /opt/postgresql_sync/daily_sync_master.sh
        ;;

    "test")
        psql -h $PGHOST -d $PGDATABASE -U $PGUSER -c "SELECT run_all_tests();"
        ;;

    "maintenance")
        psql -h $PGHOST -d $PGDATABASE -U $PGUSER -c "SELECT perform_daily_maintenance();"
        ;;

    "health-check")
        psql -h $PGHOST -d $PGDATABASE -U $PGUSER -f /opt/postgresql_sync/health_check.sql
        ;;

    *)
        echo "Usage: $0 {sync|test|maintenance|health-check} [environment]"
        exit 1
        ;;
esac
```

## KI-Assistant Integration Template

```python
#!/usr/bin/env python3
# ki_assistant_postgresql.py

import psycopg2
import json
import logging

class PostgreSQLAutomation:
    def __init__(self, config_file='/etc/postgresql_automation/config.json'):
        with open(config_file) as f:
            self.config = json.load(f)
        self.setup_logging()

    def execute_operation(self, operation_type, parameters=None):
        """Execute automated PostgreSQL operation"""
        try:
            conn = psycopg2.connect(**self.config['database'])
            cur = conn.cursor()

            if operation_type == 'create_view':
                self._create_view(cur, parameters)
            elif operation_type == 'optimize_query':
                self._optimize_query(cur, parameters)
            elif operation_type == 'refresh_materialized':
                self._refresh_materialized(cur, parameters)

            conn.commit()
            self.logger.info(f"Operation {operation_type} completed")

        except Exception as e:
            self.logger.error(f"Operation {operation_type} failed: {str(e)}")
            if conn:
                conn.rollback()
            raise
        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()
```

---
**Siehe auch**:
- [PostgreSQL Daily Ops](POSTGRESQL_DAILY_OPS.md) - Tägliche Routinen
- [Troubleshooting Datenbank](TROUBLESHOOTING_DATENBANK.md) - Problemlösung
- [PostgreSQL Referenz](../reference/POSTGRESQL_REFERENZ.md) - Technische Details
- [PostgreSQL Migration Guide](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md) - Timeline
