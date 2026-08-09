#!/bin/bash
# ---
# deployment: systemd-timer
# service: performance-monitor.service
# status: active
# type: scheduled
# requires_root: true
# timer: performance-monitor.timer
# ---
# monitor-postgres-performance.sh - system performance monitoring & logging
# Version: 2.3
# v2.3 (2026-01-05): alert cooldown implemented (1h)
# v2.2 (2025-12-10): removed unnecessary sudo calls (the file is already owned
#                    by the service account)
# v2.1 (2025-10-20): migrated to secure-file-utils.sh (1 append operation)
# v2.0 (2025-10-20): guidelines-compliant
# Date:    2025-10-20
# Purpose: monitor and log system performance metrics (CPU, RAM, disk I/O,
#          PostgreSQL)
# System:  legacy-host Linux server (Ubuntu 24.04 LTS, 64 GB RAM, PostgreSQL 16)
#
# REQUIREMENT: this script sources a shared shell library that is NOT shipped
# with the public release (see the guard below and the README). Without it the
# script exits 2 and does nothing.

set -uo pipefail  # NO -e: explicit error handling

# Source Common Library
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly SCRIPT_DIR
LOG_TAG="$(basename "$0" .sh)"
# shellcheck disable=SC2034  # read by the sourced logging library
readonly LOG_TAG

# Shared shell library. NOT shipped with the public release — it was too tied
# to the original server layout to generalise. Supply your own implementation
# of the functions listed below, or point PG_TOOLKIT_LIB_DIR at a directory
# that contains them.
LIB_DIR="${PG_TOOLKIT_LIB_DIR:-${SCRIPT_DIR}/../lib}"
readonly LIB_DIR
for _lib in logging.sh utils.sh secure-file-utils.sh; do
    if [[ ! -r "${LIB_DIR}/${_lib}" ]]; then
        echo "ERROR: required library not found: ${LIB_DIR}/${_lib}" >&2
        echo "" >&2
        echo "This script depends on a shared shell library that is not shipped" >&2
        echo "with the public release. Provide your own implementation of:" >&2
        echo "  log_info, log_warning, log_success, log_error," >&2
        echo "  send_alert_once, check_postgresql," >&2
        echo "  format_metrics_table_html, sfu_append_file" >&2
        echo "or set PG_TOOLKIT_LIB_DIR to a directory that contains them." >&2
        exit 2
    fi
    # shellcheck source=/dev/null
    source "${LIB_DIR}/${_lib}" || exit 2
done
unset _lib

# Environment (see README, "Operational scripts: what is and is not shipped"):
#   PG_MONITORING_PASSWORD  password for the read-only `monitoring` role. Was
#                           UBUNTU_POSTGRES_MONITORING_PASSWORD without a
#                           default, which tripped `set -u`; every PostgreSQL
#                           metric then silently fell back to "0"/"N/A".
#   PERF_ALERT_HIGH_LOAD    send alerts on threshold breach (default: true)
#   ALERT_EMAIL             alert recipient (default: root@localhost)

# Configuration - All readonly
readonly LOG_PREFIX="[Performance Monitor]"
readonly METRICS_LOG="/var/log/performance-metrics.log"
readonly ALERT_ON_HIGH_LOAD="${PERF_ALERT_HIGH_LOAD:-true}"

# Thresholds - All readonly
readonly CPU_LOAD_HIGH=80
readonly MEMORY_USAGE_HIGH=85
# NOTE: a DISK_IO_HIGH threshold used to be declared here but was never
# evaluated anywhere in this script. Removed rather than left standing:
# a threshold that nothing enforces reads like a guarantee that does not exist.

# Alert Cooldown (1 hour)
ALERT_COOLDOWN=3600

# Cleanup handler
cleanup() {
    log_info "$LOG_PREFIX Cleanup: Performance metrics written to $METRICS_LOG"
}
trap cleanup EXIT INT TERM

# Error trap
trap 'log_error "$LOG_PREFIX Script failed with error on line $LINENO"' ERR

# Main Function
main() {
    log_info "$LOG_PREFIX Starting performance monitoring collection"

    # Create metrics log if not exists
    if [ ! -f "$METRICS_LOG" ]; then
        touch "$METRICS_LOG"
        chmod 640 "$METRICS_LOG"
    fi

    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local metrics=""

    # === 1. CPU Metrics ===
    log_info "$LOG_PREFIX Collecting CPU metrics..."

    local cpu_cores
    cpu_cores=$(nproc)
    local load_1min
    load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | xargs)
    local load_5min
    load_5min=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $2}' | xargs)
    local load_15min
    load_15min=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $3}' | xargs)

    local cpu_load_pct
    cpu_load_pct=$(echo "$load_1min $cpu_cores" | awk '{printf("%.1f", ($1/$2) * 100)}')

    log_info "$LOG_PREFIX CPU Load: ${cpu_load_pct}% (1min: $load_1min, 5min: $load_5min, 15min: $load_15min, cores: $cpu_cores)"

    metrics+="CPU_LOAD=${cpu_load_pct}% CPU_1MIN=$load_1min CPU_5MIN=$load_5min CPU_15MIN=$load_15min CPU_CORES=$cpu_cores "

    # Alert on high CPU load
    if (( $(echo "$cpu_load_pct > $CPU_LOAD_HIGH" | bc -l) )); then
        log_warning "$LOG_PREFIX High CPU load detected: ${cpu_load_pct}%"

        if [ "$ALERT_ON_HIGH_LOAD" = "true" ]; then
            # Gather additional context for alert
            local mem_usage_pct
            mem_usage_pct=$(free | grep Mem | awk '{printf("%.0f", ($3/$2) * 100)}')
            local io_wait
            io_wait=$(iostat -c 1 2 | tail -1 | awk '{print $4}' 2>/dev/null || echo "0")
            local pg_connections
            pg_connections=$(PGPASSWORD="${PG_MONITORING_PASSWORD:-}" psql -U monitoring -h localhost -d postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs || echo "0")
            local container_count
            container_count=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l || echo "0")

            # Build performance metrics table
            local perf_metrics
            perf_metrics=$(format_metrics_table_html "PERFORMANCE METRICS" \
                "CPU Load|${cpu_load_pct}%|WARNING" \
                "Memory Usage|${mem_usage_pct}%|$([ "$mem_usage_pct" -ge 85 ] && echo "WARNING" || echo "OK")" \
                "I/O Wait|${io_wait}%|$([ "$(echo "$io_wait >= 20" | bc -l 2>/dev/null || echo 0)" -eq 1 ] && echo "WARNING" || echo "OK")" \
                "PostgreSQL Connections|${pg_connections}|OK" \
                "Docker Containers|${container_count} running|OK")

            local top_cpu_consumers
            top_cpu_consumers=$(ps aux --sort=-%cpu | head -11 | tail -10 | awk '{printf "%-20s %6s\n", $11, $3"%"}')

            send_alert_once "perf_high_cpu" "$ALERT_COOLDOWN" \
                "[Performance] High CPU Load" \
                "$perf_metrics

<p>CPU load has been at <strong>${cpu_load_pct}%</strong> for 5+ minutes (threshold: ${CPU_LOAD_HIGH}%)</p>

<strong>Load Averages:</strong>
<pre>1-min:  $load_1min
5-min:  $load_5min
15-min: $load_15min
Cores:  $cpu_cores</pre>

<strong>Top CPU Consumers (Top 10):</strong>
<pre>PROCESS              CPU%
$top_cpu_consumers</pre>" \
                "" \
                "1. Check top processes: <code>top -b -n 1 | head -20</code>
2. Identify CPU hogs: <code>ps aux --sort=-%cpu | head -15</code>
3. Check for runaway processes: <code>systemctl list-units --failed</code>
4. Review recent changes: <code>journalctl --since '1 hour ago' | grep -i error</code>
5. Check I/O wait: <code>iostat -x 1 5</code>
6. Consider scaling or optimization
7. Emergency: Nice down process: <code>renice +10 -p PID</code>" \
                "⚠️  Performance degradation possible
⚠️  Response times may increase
⚠️  Service slowdown expected
ℹ️  Normal spikes: backups (03:00), VS Code builds, cron jobs
ℹ️  Sustained >85%: Investigation required" \
                "<repo>/docs/operations/CPU_TUNING.md" \
                "${ALERT_EMAIL:-root@localhost}"
        fi
    fi

    # === 2. Memory Metrics ===
    log_info "$LOG_PREFIX Collecting memory metrics..."

    local mem_total
    mem_total=$(free -m | grep Mem | awk '{print $2}')
    local mem_used
    mem_used=$(free -m | grep Mem | awk '{print $3}')
    local mem_available
    mem_available=$(free -m | grep Mem | awk '{print $7}')
    local mem_usage_pct
    mem_usage_pct=$(free | grep Mem | awk '{printf("%.1f", ($3/$2) * 100)}')

    log_info "$LOG_PREFIX Memory: ${mem_usage_pct}% used (${mem_used}MB / ${mem_total}MB, available: ${mem_available}MB)"

    metrics+="MEM_USAGE=${mem_usage_pct}% MEM_USED=${mem_used}MB MEM_TOTAL=${mem_total}MB MEM_AVAILABLE=${mem_available}MB "

    # Alert on high memory usage
    if (( $(echo "$mem_usage_pct > $MEMORY_USAGE_HIGH" | bc -l) )); then
        log_warning "$LOG_PREFIX High memory usage detected: ${mem_usage_pct}%"

        if [ "$ALERT_ON_HIGH_LOAD" = "true" ]; then
            # Gather system context
            local cpu_load_current
            cpu_load_current=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | xargs)
            local cpu_cores_current
            cpu_cores_current=$(nproc)
            local cpu_load_pct_current
            cpu_load_pct_current=$(echo "$cpu_load_current $cpu_cores_current" | awk '{printf("%.0f", ($1/$2) * 100)}')

            # Build system metrics table
            local system_metrics
            system_metrics=$(format_metrics_table_html "SYSTEM STATUS" \
                "Memory Usage|${mem_usage_pct}%|WARNING" \
                "CPU Load|${cpu_load_pct_current}%|$([ "$cpu_load_pct_current" -ge 85 ] && echo "WARNING" || echo "OK")" \
                "Memory Available|${mem_available}MB|OK" \
                "Swap Used|$(free -m | grep Swap | awk '{print $3}')MB|OK")

            local mem_detail
            mem_detail=$(free -h)
            local top_mem_consumers
            top_mem_consumers=$(ps aux --sort=-%mem | head -11 | tail -10 | awk '{printf "%-20s %6s %8s\n", $11, $4"%", $6}')

            send_alert_once "perf_high_memory" "$ALERT_COOLDOWN" \
                "[Performance] High Memory Usage" \
                "$system_metrics

<p>System memory usage is at <strong>${mem_usage_pct}%</strong> (threshold: ${MEMORY_USAGE_HIGH}%)</p>

<strong>Memory Details:</strong>
<pre>$mem_detail</pre>

<strong>Top Memory Consumers (Top 10):</strong>
<pre>PROCESS              MEM%     VSZ
$top_mem_consumers</pre>" \
                "" \
                "1. Check memory usage: <code>free -h</code>
2. Identify memory hogs: <code>ps aux --sort=-%mem | head -15</code>
3. Check for memory leaks: <code>systemctl status postgresql</code>
4. Check PostgreSQL connections: <code>psql -U monitoring -d postgres -c \"SELECT count(*) FROM pg_stat_activity;\"</code>
5. Check Docker memory: <code>docker stats --no-stream</code>
6. Restart high-memory service (if identified): <code>sudo systemctl restart SERVICE</code>
7. Emergency: Drop caches: <code>echo 3 | sudo tee /proc/sys/vm/drop_caches</code>" \
                "⚠️  Performance degradation at >90%
⚠️  OOM killer may terminate processes at >95%
⚠️  Service crashes possible
ℹ️  Normal usage: 50-80% with 64GB RAM" \
                "<repo>/docs/operations/MEMORY_TUNING.md" \
                "${ALERT_EMAIL:-root@localhost}"
        fi
    fi

    # === 3. Disk I/O Metrics ===
    log_info "$LOG_PREFIX Collecting disk I/O metrics..."

    local disk_read_mb=0
    local disk_write_mb=0

    if command -v iostat &> /dev/null; then
        # Get disk I/O stats (MB/s)
        local io_stats
        io_stats=$(iostat -d -m -x 1 2 | grep -E "^(nvme|md)" | tail -3)

        disk_read_mb=$(echo "$io_stats" | awk '{sum += $6} END {printf("%.1f", sum)}')
        disk_write_mb=$(echo "$io_stats" | awk '{sum += $7} END {printf("%.1f", sum)}')

        log_info "$LOG_PREFIX Disk I/O: Read ${disk_read_mb}MB/s, Write ${disk_write_mb}MB/s"

        metrics+="DISK_READ=${disk_read_mb}MB/s DISK_WRITE=${disk_write_mb}MB/s "
    else
        log_warning "$LOG_PREFIX iostat not available, skipping disk I/O metrics"
        metrics+="DISK_READ=N/A DISK_WRITE=N/A "
    fi

    # === 4. RAID Performance ===
    if [ -e "/proc/mdstat" ]; then
        local raid_status
        raid_status=$(grep -E "active|UU|U_|_U" /proc/mdstat | head -1)
        log_info "$LOG_PREFIX RAID Status: $raid_status"
        metrics+="RAID_STATUS=\"$raid_status\" "
    fi

    # === 5. PostgreSQL Performance ===
    log_info "$LOG_PREFIX Collecting PostgreSQL metrics..."

    if check_postgresql; then
        # Active connections
        local pg_connections
        pg_connections=$(PGPASSWORD="${PG_MONITORING_PASSWORD:-}" psql -U monitoring -h localhost -d postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs || echo "0")

        # Database size (largest DB)
        local pg_largest_db
        pg_largest_db=$(PGPASSWORD="${PG_MONITORING_PASSWORD:-}" psql -U monitoring -h localhost -d postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres') ORDER BY pg_database_size(datname) DESC LIMIT 1;" 2>/dev/null | xargs || echo "N/A")
        local pg_largest_db_size
        pg_largest_db_size=$(PGPASSWORD="${PG_MONITORING_PASSWORD:-}" psql -U monitoring -h localhost -d postgres -t -c "SELECT pg_size_pretty(pg_database_size('$pg_largest_db'));" 2>/dev/null | xargs || echo "N/A")

        # Cache hit ratio (should be > 99%)
        local pg_cache_hit_ratio
        pg_cache_hit_ratio=$(PGPASSWORD="${PG_MONITORING_PASSWORD:-}" psql -U monitoring -h localhost -d postgres -t -c "SELECT ROUND((sum(heap_blks_hit) / NULLIF((sum(heap_blks_hit) + sum(heap_blks_read)), 0)) * 100, 2) FROM pg_statio_user_tables;" 2>/dev/null | xargs || echo "N/A")

        log_info "$LOG_PREFIX PostgreSQL: $pg_connections connections, largest DB: $pg_largest_db ($pg_largest_db_size), cache hit: ${pg_cache_hit_ratio}%"

        metrics+="PG_CONNECTIONS=$pg_connections PG_LARGEST_DB=\"$pg_largest_db\" PG_LARGEST_DB_SIZE=\"$pg_largest_db_size\" PG_CACHE_HIT=${pg_cache_hit_ratio}% "

        # Alert on low cache hit ratio
        if [ "$pg_cache_hit_ratio" != "N/A" ] && (( $(echo "$pg_cache_hit_ratio < 95" | bc -l) )); then
            log_warning "$LOG_PREFIX PostgreSQL cache hit ratio is low: ${pg_cache_hit_ratio}%"
        fi
    else
        log_warning "$LOG_PREFIX PostgreSQL is not running, skipping PostgreSQL metrics"
        metrics+="PG_STATUS=DOWN "
    fi

    # === 6. Docker Container Stats ===
    log_info "$LOG_PREFIX Collecting Docker container metrics..."

    if systemctl is-active --quiet docker; then
        local webapp_status
        webapp_status=$(docker inspect -f '{{.State.Status}}' webapp 2>/dev/null || echo "not_found")
        local webapp_uptime
        webapp_uptime=$(docker inspect -f '{{.State.StartedAt}}' webapp 2>/dev/null || echo "N/A")

        log_info "$LOG_PREFIX Docker: WebApp status: $webapp_status (started: $webapp_uptime)"

        metrics+="DOCKER_WEBAPP=$webapp_status "
    else
        log_warning "$LOG_PREFIX Docker is not running, skipping container metrics"
        metrics+="DOCKER_STATUS=DOWN "
    fi

    # === 7. System Uptime ===
    local uptime_seconds
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    local uptime_days
    uptime_days=$(echo "$uptime_seconds / 86400" | bc)
    local uptime_pretty
    uptime_pretty=$(uptime -p)

    log_info "$LOG_PREFIX System uptime: $uptime_pretty"

    metrics+="UPTIME=\"$uptime_pretty\" UPTIME_DAYS=$uptime_days "

    # === 8. Write metrics to log ===
    sfu_append_file "[$timestamp] $metrics" "$METRICS_LOG"

    log_success "$LOG_PREFIX Performance metrics collected and logged to $METRICS_LOG"

    # Optional: Log rotation (keep last 10000 lines, ~7 days at 15min intervals)
    local log_lines
    log_lines=$(wc -l < "$METRICS_LOG")
    if [ "$log_lines" -gt 10000 ]; then
        log_info "$LOG_PREFIX Rotating metrics log (current lines: $log_lines)"
        tail -5000 "$METRICS_LOG" > "$METRICS_LOG.tmp"
        mv "$METRICS_LOG.tmp" "$METRICS_LOG"
    fi

    exit 0
}

# Execute main function
main "$@"
