# PostgreSQL 16 Tuning Reference & Deployment Guide

> Consolidated reference for tuning PostgreSQL 16 on a dedicated 64 GB RAM /
> NVMe host, plus the deployment, verification, and troubleshooting workflow
> that goes with it. Extracted from a production deployment and anonymised.

**Companion file**: [`config/postgres-tuning-64gb.conf`](../../config/postgres-tuning-64gb.conf) — the actual configuration overrides.

---

## Part 1 — Configuration Reference

## TL;DR (20 Worte)

Memory Tuning (64GB RAM), NVMe SSD Optimierung, Authentication Rules (pg_hba.conf), Logging, Autovacuum und pg_stat_statements.

---

## Essential Context

> **DIATAXIS Category**: Reference (Information-Oriented)
> **Audience**: Database-Admins, die PostgreSQL 16 auf 64GB RAM optimieren

**Zweck**: Vollstaendige Konfigurationsreferenz fuer alle drei PostgreSQL Config-Files: Memory/SSD/Connection Tuning, Authentication Rules und erweiterte Settings (Logging, Autovacuum, Extensions).

**Scope**: Memory Configuration (shared_buffers 16GB, effective_cache_size 48GB, work_mem 128MB), NVMe SSD Optimierung (random_page_cost 1.1, effective_io_concurrency 200), pg_hba.conf Authentication (Local, LAN, Developer Sandbox), Advanced Settings (WAL, Logging, Autovacuum, pg_stat_statements).

**Abgrenzung**: Deployment Workflow und Troubleshooting → [`POSTGRESQL_DAILY_OPS.md`](../how-to/POSTGRESQL_DAILY_OPS.md) und [`TROUBLESHOOTING_DATENBANK.md`](../how-to/TROUBLESHOOTING_DATENBANK.md).

---

<details id="memory-configuration">
<summary><b>Memory Configuration</b> - 64GB RAM Tuning (click to expand)</summary>

## Memory Configuration (64GB RAM)

### Tuning-Regeln (PostgreSQL Best Practices)

**Hardware**: AMD Ryzen 5 5600GT, 64GB DDR4-3200

**Memory-Allocation**:
- **shared_buffers**: 25% of RAM → **16GB**
- **effective_cache_size**: 75% of RAM → **48GB**
- **work_mem**: Conservative start → **128MB** (per query operation)
- **maintenance_work_mem**: 5% of RAM, max 2GB → **2GB**

---

### shared_buffers = 16GB

**Zweck**: PostgreSQL's own cache (Hot Data in Memory)

**Rule**: 25% of RAM fuer dedicated PostgreSQL-Server

**Impact**:
- Haeufig genutzte Tables/Indexes in RAM
- Reduziert Disk I/O
- Verbessert Query-Performance

**Verify**:
```bash
sudo -u postgres psql -c "SHOW shared_buffers;"
# Output: 16GB
```

---

### effective_cache_size = 48GB

**Zweck**: Query Planner Hint (Total available Memory for Caching)

**Rule**: 75% of RAM (inkl. OS Page Cache)

**Impact**:
- Bessere Query-Plans (Index vs Sequential Scan Entscheidungen)
- KEINE tatsaechliche Memory-Allokation (nur Hint fuer Planner)

**Verify**:
```bash
sudo -u postgres psql -c "SHOW effective_cache_size;"
# Output: 48GB
```

---

### work_mem = 128MB

**Zweck**: Memory per query operation (Sort, Hash, Aggregation)

**Rule**: Conservative start (128MB), increase wenn temp files zu gross

**Impact**:
- Verhindert Disk-Spill bei Sorts/Hashes
- Achtung: `work_mem * max_connections` kann viel RAM nutzen!
- 128MB * 100 connections = 12.8GB max (OK bei 64GB)

**Monitor temp file usage**:
```bash
sudo journalctl -u postgresql | grep "temporary file"
```

**Increase if needed**:
```sql
-- Per-Session Override (Test)
SET work_mem = '256MB';
```

---

### maintenance_work_mem = 2GB

**Zweck**: Memory fuer Maintenance-Operationen (VACUUM, CREATE INDEX, ALTER TABLE)

**Rule**: 5% of RAM, max 2GB (PostgreSQL Limit)

**Impact**:
- Schnellere VACUUM-Operationen
- Schnellere Index-Creation
- Nicht relevant fuer normale Queries

**Verify**:
```bash
sudo -u postgres psql -c "SHOW maintenance_work_mem;"
# Output: 2GB
```

---

### max_connections = 100

**Zweck**: Maximum concurrent connections

**Rule**: Moderate fuer besseres Memory-Management (jede Connection nutzt RAM)

**Impact**:
- 100 Connections ausreichend fuer WebApp, DocApp, Management-Dashboards
- Bei Bedarf Connection Pooling via **pgBouncer** (Port 6432)

**Monitor active connections**:
```bash
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

</details>

---

<details id="authentication-rules">
<summary><b>Authentication Rules</b> - pg_hba.conf (click to expand)</summary>

## Authentication Rules (pg_hba.conf)

### Format
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
```

---

### Local Connections (Unix Sockets)

```conf
# postgres user - peer authentication (no password)
local   all             postgres                                peer

# All other users - md5 authentication (password)
local   all             all                                     md5
```

**peer**: User muss als OS-User `postgres` eingeloggt sein
**md5**: Password-based authentication

---

### IPv4 Localhost Connections

```conf
# Localhost (127.0.0.1)
host    all             all             127.0.0.1/32            md5
```

**Use Case**: Local applications (DocApp Container, WebApp Container)

---

### LAN Connections (Management-Dashboards)

```conf
# Admin user account - LAN access
host    all             dbadmin            10.0.0.0/8          md5
```

**Use Case**: Power BI, pgAdmin, DBeaver von Windows-Office-PC (10.0.0.10)

**Security**:
- Beschraenkt auf LAN (10.0.0.0/8)
- Password-based authentication (md5)
- Kein Internet-Access (UFW blocked)

---

### Developer's Sandbox (Localhost-Only)

```conf
# Developer's test database - localhost only
host    developer_test     developer          127.0.0.1/32            md5
```

**Security**:
- NUR localhost (127.0.0.1/32)
- Kein LAN-Access moeglich
- Isoliert von Production-Daten

**Testing**:
```bash
# Should work (localhost)
psql -U developer -d developer_test -h localhost

# Should be DENIED (LAN)
psql -U developer -d developer_test -h 10.0.0.20
# Output: FATAL:  no pg_hba.conf entry for host...
```

---

### IPv6 Connections

```conf
# IPv6 localhost
host    all             all             ::1/128                 md5
```

---

### Deployment Workflow (pg_hba.conf)

```bash
# 1. Backup current pg_hba.conf
sudo cp /etc/postgresql/16/main/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf.backup

# 2. Edit pg_hba.conf (manuale Uebernahme aus Template)
sudo nano /etc/postgresql/16/main/pg_hba.conf

# 3. Reload (KEIN Restart noetig!)
sudo systemctl reload postgresql

# 4. Check Logs fuer Fehler
sudo journalctl -u postgresql -n 20

# 5. Test Connections
psql -U dbadmin -d postgres -h localhost         # Should work
psql -U developer -d developer_test -h localhost    # Should work
```

**WICHTIG**: `systemctl reload` (KEIN Restart noetig fuer pg_hba.conf Aenderungen!)

</details>

---

<details id="advanced-settings">
<summary><b>Advanced Settings</b> - NVMe SSD, WAL, Logging, Autovacuum, Extensions (click to expand)</summary>

## Advanced Settings

### NVMe SSD Optimization

**Hardware**: 2x 1TB Samsung 990 EVO Plus NVMe SSD (RAID 1)

```ini
# random_page_cost: Cost of random disk page fetch
# NVMe SSDs have near-zero random access penalty (default: 4.0)
random_page_cost = 1.1

# effective_io_concurrency: Number of concurrent I/O operations
# NVMe can handle many concurrent operations (default: 1)
effective_io_concurrency = 200
```

**Impact**:
- Query Planner bevorzugt Index Scans (wegen low random_page_cost)
- Parallel I/O fuer bessere Throughput (effective_io_concurrency 200)

---

### Checkpoint & WAL Settings

```ini
wal_buffers = 16MB
checkpoint_completion_target = 0.9
max_wal_size = 4GB
min_wal_size = 1GB
wal_level = replica
```

**Impact**:
- Bessere Write-Performance (groessere WAL vor Checkpoint)
- Laengere Recovery-Zeit bei Crash (Trade-off)
- Replication-ready (wal_level replica)

---

### Logging & Monitoring

```ini
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
```

**Monitoring**:
```bash
# Slow queries (>1000ms)
sudo journalctl -u postgresql | grep "duration:"

# Temp file usage
sudo journalctl -u postgresql | grep "temporary file"
```

---

### Autovacuum Tuning

```ini
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05
```

**Monitoring**:
```bash
sudo -u postgres psql -c "SELECT schemaname, tablename, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables ORDER BY last_autovacuum DESC NULLS LAST LIMIT 10;"
```

---

### Performance Extensions (pg_stat_statements)

```ini
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
```

**Enable Extension**:
```bash
sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

**Usage**:
```sql
-- Top 10 slowest queries
SELECT
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

</details>

---

## Related Documentation

- **[`POSTGRESQL_REFERENZ.md`](POSTGRESQL_REFERENZ.md)** - PostgreSQL Overview, Setup, Config, Data Types
- **[`POSTGRESQL_DAILY_OPS.md`](../how-to/POSTGRESQL_DAILY_OPS.md)** - Daily Routines, Maintenance
- **[`POSTGRESQL_AUTOMATION.md`](../how-to/POSTGRESQL_AUTOMATION.md)** - Automated Operations, Emergency Response
- **[`TROUBLESHOOTING_DATENBANK.md`](../how-to/TROUBLESHOOTING_DATENBANK.md)** - Performance Diagnostics

---

## Part 2 — Deployment, Verification & Troubleshooting

## Deployment Workflow

### Option 1: Automatisches Deployment (Empfohlen)

```bash
# Via initial-setup.sh
sudo ./scripts/setup/initial-setup.sh

# Deployed:
# - postgresql.conf.override -> /etc/postgresql/16/main/conf.d/tuning-overrides.conf
# - PostgreSQL Restart
# - pg_stat_statements Extension aktiviert
```

---

### Option 2: Manuelles Deployment

#### Step 1: Backup

```bash
# Backup current config
sudo cp /etc/postgresql/16/main/conf.d/tuning-overrides.conf /etc/postgresql/16/main/conf.d/tuning-overrides.conf.backup

# Backup pg_hba.conf
sudo cp /etc/postgresql/16/main/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf.backup
```

#### Step 2: Deploy postgresql.conf.override

```bash
# Copy to conf.d/
sudo cp configs/postgresql/postgresql.conf.override /etc/postgresql/16/main/conf.d/tuning-overrides.conf

# Syntax-Check (WICHTIG!)
sudo -u postgres /usr/lib/postgresql/16/bin/postgres -D /var/lib/postgresql/16/main --check
# Expected Output: (silence = success)
```

#### Step 3: Deploy pg_hba.conf (manual)

```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/16/main/pg_hba.conf

# Add/Modify relevant sections from pg_hba.conf.template:
# - Local connections
# - LAN access for dbadmin
# - Developer localhost-only
```

#### Step 4: Apply Changes

```bash
# Restart PostgreSQL (fuer postgresql.conf changes)
sudo systemctl restart postgresql

# OR: Reload (fuer pg_hba.conf changes, kein Restart)
sudo systemctl reload postgresql

# Check Status
systemctl status postgresql
```

#### Step 5: Verify Settings

```bash
# Memory Settings
sudo -u postgres psql -c "SHOW shared_buffers;"         # Should be 16GB
sudo -u postgres psql -c "SHOW effective_cache_size;"   # Should be 48GB
sudo -u postgres psql -c "SHOW work_mem;"               # Should be 128MB
sudo -u postgres psql -c "SHOW max_connections;"        # Should be 100

# NVMe Settings
sudo -u postgres psql -c "SHOW random_page_cost;"       # Should be 1.1
sudo -u postgres psql -c "SHOW effective_io_concurrency;" # Should be 200
```

#### Step 6: Enable pg_stat_statements

```bash
sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
sudo -u postgres psql -c "\dx"
# Should list pg_stat_statements
```

---

### Option 3: Git-Workflow (Config-Aenderungen)

```bash
# 1. Edit Config im Repository
nano configs/postgresql/postgresql.conf.override

# 2. Deploy nach Production
sudo cp configs/postgresql/postgresql.conf.override /etc/postgresql/16/main/conf.d/tuning-overrides.conf

# 3. Syntax-Check
sudo -u postgres /usr/lib/postgresql/16/bin/postgres -D /var/lib/postgresql/16/main --check

# 4. Restart PostgreSQL
sudo systemctl restart postgresql

# 5. Verify
systemctl status postgresql
sudo journalctl -u postgresql -n 20
```

</details>

---

<details id="performance-verification">
<summary><b>Performance Verification</b> - Metriken, Baselines, Monitoring-Queries (click to expand)</summary>

## Performance Verification

### Quick Health Check

```bash
# 1. PostgreSQL Status
systemctl status postgresql

# 2. Active Connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# 3. Database Sizes
sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC;"

# 4. Cache Hit Ratio (should be >90%)
sudo -u postgres psql -c "SELECT sum(blks_hit)*100/sum(blks_hit+blks_read) AS cache_hit_ratio FROM pg_stat_database WHERE datname NOT IN ('template0', 'template1');"

# 5. Slow Queries (>1000ms)
sudo journalctl -u postgresql --since "1 hour ago" | grep "duration:" | tail -10
```

---

### Expected Baselines (Stand 11.02.2026)

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| **Cache Hit Ratio** | >90% | ~95% | Exzellent |
| **Avg Query Time** | <10ms | ~2-5ms | Exzellent |
| **Active Connections** | <50 | 10-20 (Peak: 40) | OK |
| **Database Size WebApp** | N/A | ~500MB | OK |
| **shared_buffers Usage** | N/A | ~12GB / 16GB | OK |

---

### pg_stat_statements (Top Queries)

```sql
-- Connect to database
sudo -u postgres psql

-- Top 10 slowest queries (by mean time)
SELECT
    substring(query, 1, 60) AS query_preview,
    calls,
    round(total_time::numeric, 2) AS total_time_ms,
    round(mean_time::numeric, 2) AS mean_time_ms,
    round(max_time::numeric, 2) AS max_time_ms
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

---

### Connection Monitoring

```sql
-- Active connections by database
SELECT datname, count(*) AS connections
FROM pg_stat_activity
GROUP BY datname
ORDER BY connections DESC;

-- Long-running queries (>1 minute)
SELECT pid, usename, datname, state,
    now() - query_start AS duration,
    substring(query, 1, 100) AS query_preview
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '1 minute'
ORDER BY duration DESC;
```

---

### Autovacuum Monitoring

```sql
SELECT schemaname, tablename,
    last_vacuum, last_autovacuum,
    last_analyze, last_autoanalyze,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC NULLS LAST
LIMIT 20;
```

</details>

---

<details id="troubleshooting">
<summary><b>Troubleshooting</b> - 6 haeufige Probleme (click to expand)</summary>

## Troubleshooting

### PostgreSQL startet nicht nach Config-Aenderung

**Symptom**: `systemctl status postgresql` zeigt `failed`

**Debug**:
```bash
sudo journalctl -u postgresql -n 50
sudo -u postgres /usr/lib/postgresql/16/bin/postgres -D /var/lib/postgresql/16/main --check
# Common Errors: Invalid parameter name, invalid value (z.B. "16G" statt "16GB")
```

**Fix**:
```bash
# Restore Backup
sudo cp /etc/postgresql/16/main/conf.d/tuning-overrides.conf.backup /etc/postgresql/16/main/conf.d/tuning-overrides.conf
sudo systemctl restart postgresql

# Fix Config und re-deploy mit Syntax-Check
```

---

### Connection refused (LAN)

**Symptom**: `psql -U dbadmin -h 10.0.0.20` → `Connection refused`

**Debug**:
```bash
sudo netstat -tulpn | grep 5432
sudo -u postgres psql -c "SHOW listen_addresses;"
# Should be: * (all interfaces)
```

**Fix**:
```bash
# Edit /etc/postgresql/16/main/postgresql.conf (NICHT conf.d/!)
sudo nano /etc/postgresql/16/main/postgresql.conf
# Find: listen_addresses = '*'
sudo systemctl restart postgresql
```

---

### Authentication failed (pg_hba.conf)

**Symptom**: `FATAL: no pg_hba.conf entry for host...`

**Fix**:
```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
# Add: host    all    dbadmin    10.0.0.0/8    md5
sudo systemctl reload postgresql   # Reload, KEIN Restart!
```

---

### Slow Queries (temp file usage)

**Symptom**: Logs zeigen viele "temporary file" Messages

**Root Cause**: work_mem zu klein (Sort/Hash spills to disk)

**Fix**:
```bash
# Test per-session
sudo -u postgres psql -c "SET work_mem = '256MB';"

# Global (wenn bestaetigt)
# Edit: work_mem = 256MB in postgresql.conf.override
sudo systemctl restart postgresql
```

---

### Low Cache Hit Ratio (<90%)

**Debug**:
```bash
sudo -u postgres psql -c "SELECT sum(blks_hit)*100/sum(blks_hit+blks_read) AS cache_hit_ratio FROM pg_stat_database WHERE datname NOT IN ('template0', 'template1');"
```

**Fix**: shared_buffers erhoehen oder nach Cold-Start-Phase warten (Cache fuellt sich selbst).

---

### pg_stat_statements not working

**Symptom**: `ERROR: relation "pg_stat_statements" does not exist`

**Fix**:
```bash
# 1. Pruefen ob shared_preload_libraries gesetzt
sudo -u postgres psql -c "SHOW shared_preload_libraries;"
# Should include: pg_stat_statements

# 2. Restart (required for shared_preload_libraries)
sudo systemctl restart postgresql

# 3. Extension erstellen
sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

</details>

---

## Related Documentation

- **[Part 1 — Configuration](#part-1--configuration-reference)** - Memory Configuration, Authentication, Advanced Settings (top of this file)
- **[`POSTGRESQL_REFERENZ.md`](POSTGRESQL_REFERENZ.md)** - PostgreSQL Overview, Setup, Data Types
- **[`scripts/backup-postgres.sh`](../../scripts/backup-postgres.sh)** - PostgreSQL Backup Script (companion implementation)
- **[`scripts/monitor-postgres-performance.sh`](../../scripts/monitor-postgres-performance.sh)** - Performance Monitor Script
