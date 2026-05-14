# PostgreSQL Core Commands - Template

## 🔑 Essential Connection Pattern
```bash
# Standard psql-Befehl für alle Operationen
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SQL_HIER\""
```

## ⚡ Instant Commands

### Schema Operations
```bash
# Create Schema
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"CREATE SCHEMA IF NOT EXISTS order_processing;\""

# Set Search Path
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SET search_path TO order_processing, public;\""
```

### Quick Health Check
```bash
# Database Size
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT pg_size_pretty(pg_database_size('postgres'));\""

# Connection Count
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT count(*) FROM pg_stat_activity;\""

# Long Running Queries
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT query, query_start FROM pg_stat_activity WHERE state = 'active' AND query_start < CURRENT_TIMESTAMP - INTERVAL '5 minutes';\""
```

### Emergency Commands
```bash
# Kill Long Queries
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND query_start < CURRENT_TIMESTAMP - INTERVAL '10 minutes';\""

# Quick VACUUM
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"VACUUM ANALYZE;\""
```