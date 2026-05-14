# PostgreSQL Daily Operations - Template

## 📋 Daily Health Check Procedures

### Morning Checks (5 Minutes)
```bash
# 1. Connection Health
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT count(*) as connections, (SELECT setting FROM pg_settings WHERE name = 'max_connections') as max_conn FROM pg_stat_activity;\""

# 2. Database Size Monitoring
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT pg_size_pretty(pg_database_size('postgres')) as db_size;\""

# 3. Recent Error Check
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT message FROM pg_log WHERE log_time > CURRENT_TIMESTAMP - INTERVAL '24 hours' AND elevel >= 20 LIMIT 5;\""
```

### Automated Health Check (Comprehensive)
```bash
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM daily_health_check();\""
```

## 🛠️ Maintenance Operations

### Weekly Maintenance (Sundays)
```bash
# 1. Intelligent VACUUM
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT intelligent_vacuum();\""

# 2. Partition Maintenance
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT maintain_partitions();\""

# 3. Performance Analysis
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM analyze_slow_queries(1000);\""
```

## 📊 Performance Monitoring

### Real-time Monitoring
```bash
# Active Queries
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT pid, query_start, state, query FROM pg_stat_activity WHERE state = 'active';\""

# Lock Monitoring
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SELECT * FROM pg_locks WHERE NOT granted;\""
```