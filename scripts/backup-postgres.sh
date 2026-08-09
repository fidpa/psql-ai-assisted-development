#!/bin/bash
# ---
# deployment: systemd-timer
# service: backup-postgresql.service
# status: active
# type: admin
# requires_root: true
# timer: backup-postgresql.timer
# ---
# backup-postgres.sh - automated PostgreSQL backup
# Version: 2.2 (zstd compression + alert cooldown)
# Date:    2025-12-16
# v2.2 (2026-01-05): alert cooldown implemented (24h)
# Purpose: daily PostgreSQL backup via pg_dumpall, with compression and
#          retention management
# System:  legacy-host Linux server (Ubuntu 24.04 LTS, PostgreSQL 16, 64 GB RAM)
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
#
# The path used to be ${SCRIPT_DIR}/../../../lib, which resolves to a directory
# three levels ABOVE the repository root — a leftover from the original tree.
LIB_DIR="${PG_TOOLKIT_LIB_DIR:-${SCRIPT_DIR}/../lib}"
readonly LIB_DIR
for _lib in logging.sh utils.sh; do
    if [[ ! -r "${LIB_DIR}/${_lib}" ]]; then
        echo "ERROR: required library not found: ${LIB_DIR}/${_lib}" >&2
        echo "" >&2
        echo "This script depends on a shared shell library that is not shipped" >&2
        echo "with the public release. Provide your own implementation of:" >&2
        echo "  log_info, log_warning, log_success, log_error," >&2
        echo "  send_alert, send_alert_once, check_postgresql, check_raid_status," >&2
        echo "  format_metrics_table_html, redact_sensitive_data" >&2
        echo "or set PG_TOOLKIT_LIB_DIR to a directory that contains them." >&2
        exit 2
    fi
    # shellcheck source=/dev/null
    source "${LIB_DIR}/${_lib}" || exit 2
done
unset _lib

# Configuration - All readonly
readonly BACKUP_DIR="/postgresql/backups"
readonly RETENTION_DAYS=7
readonly ALERT_COOLDOWN=86400  # 24 hours (daily timer)
DATE=$(date +%Y%m%d_%H%M%S)
readonly DATE
readonly BACKUP_FILE="$BACKUP_DIR/all_databases_$DATE.sql"
readonly LOG_PREFIX="[PostgreSQL Backup]"

# Cleanup handler
cleanup() {
    log_info "$LOG_PREFIX Cleanup: Checking for temporary files..."
    # Remove temporary backup file if exists (uncompressed)
    if [[ -f "$BACKUP_FILE" ]]; then
        log_info "$LOG_PREFIX Removing temporary uncompressed backup file"
        rm -f "$BACKUP_FILE"
    fi
    log_info "$LOG_PREFIX Cleanup completed"
}
trap cleanup EXIT INT TERM

# Error trap
trap 'log_error "$LOG_PREFIX Script failed with error on line $LINENO"' ERR

# Main Function
main() {
    log_info "$LOG_PREFIX Starting PostgreSQL backup process"

    # Check if PostgreSQL is running
    if ! check_postgresql; then
        log_error "$LOG_PREFIX PostgreSQL service is not running!"
        send_alert_once "backup_postgres_service_down" "$ALERT_COOLDOWN" \
            "[PostgreSQL Backup] CRITICAL: Service Down" \
            "PostgreSQL 16 service is <strong>NOT RUNNING!</strong>

<strong>Service Status:</strong> Backup aborted - PostgreSQL service must be running for pg_dumpall to execute.
<strong>Scheduled Time:</strong> Daily 03:00 (systemd timer: backup-postgresql.timer)
<strong>Backup Directory:</strong> $BACKUP_DIR" \
            "${ALERT_EMAIL:-root@localhost}" \
            "1. Check service status: <code>systemctl status postgresql</code>
2. Check detailed logs: <code>journalctl -u postgresql -n 50</code>
3. Check disk space: <code>df -h /postgresql</code>
4. Attempt restart: <code>sudo systemctl restart postgresql</code>
5. Verify PostgreSQL is running: <code>sudo -u postgres psql -c 'SELECT version();'</code>
6. Re-run backup manually: <code>sudo systemctl start backup-postgresql.service</code>
7. If restart fails: See runbook for detailed recovery procedures" \
            "🔴 <strong>NO BACKUPS CREATED!</strong>
❌ RPO (Recovery Point Objective) at risk
❌ Last backup may be 24+ hours old
⚠️  Database vulnerable to data loss
⚠️  Check PostgreSQL logs for root cause
ℹ️  Scheduled backup runs daily at 03:00" \
            "<repo>/docs/services/POSTGRESQL_RECOVERY.md"
        exit 1
    fi

    log_success "$LOG_PREFIX PostgreSQL service is running"

    # Check RAID status (warning only, not critical)
    if ! check_raid_status; then
        log_warning "$LOG_PREFIX RAID is degraded! Backup will proceed, but RAID needs attention."

        raid_status=$(cat /proc/mdstat 2>/dev/null || echo "Unable to read RAID status")
        raid_detail=$(sudo mdadm --detail /dev/md0 2>/dev/null || echo "Unable to read mdadm details")

        send_alert_once "backup_postgres_raid_degraded" "$ALERT_COOLDOWN" \
            "[PostgreSQL Backup] WARNING: RAID Degraded" \
            "RAID array /dev/md0 is <strong>DEGRADED</strong> while PostgreSQL backup is running.

<strong>Current RAID Status:</strong>
<pre>$raid_status</pre>

<strong>Detailed mdadm Status:</strong>
<pre>$raid_detail</pre>

<strong>Backup Status:</strong> Backup will proceed, but RAID requires immediate attention after completion." \
            "${ALERT_EMAIL:-root@localhost}" \
            "1. <strong>Let backup complete first</strong> (do not interrupt!)
2. After backup: Check RAID status: <code>cat /proc/mdstat</code>
3. Check which drive failed: <code>sudo mdadm --detail /dev/md0 | grep -E 'faulty|removed'</code>
4. Order replacement drive immediately (Samsung 990 EVO Plus 1TB)
5. See RAID runbook for detailed drive replacement procedure
6. Monitor backup completion: <code>journalctl -u backup-postgresql.service -f</code>" \
            "⚠️  RAID vulnerable during backup execution
⚠️  <strong>NO REDUNDANCY</strong> until drive replaced
⚠️  Data loss risk if second drive fails during backup
ℹ️  Backup will complete normally
ℹ️  Priority: Replace failed drive within 24 hours" \
            "<repo>/docs/operations/RAID_RECOVERY.md"
    else
        log_success "$LOG_PREFIX RAID status is healthy"
    fi

    # Check if backup directory exists, create if not
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "$LOG_PREFIX Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        chmod 750 "$BACKUP_DIR"
    fi

    # Check available disk space (require at least 10GB free)
    AVAILABLE_SPACE=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=10485760  # 10GB in KB

    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_error "$LOG_PREFIX Insufficient disk space! Available: $((AVAILABLE_SPACE / 1024 / 1024))GB, Required: 10GB"

        # Gather disk usage metrics
        disk_metrics=$(format_metrics_table_html "DISK SPACE STATUS" \
            "/postgresql|$(df -h /postgresql | tail -1 | awk '{print $5}')|$([ "$(df /postgresql | tail -1 | awk '{print $5}' | sed 's/%//')" -ge 90 ] && echo "CRITICAL" || echo "WARNING")" \
            "/|$(df -h / | tail -1 | awk '{print $5}')|$([ "$(df / | tail -1 | awk '{print $5}' | sed 's/%//')" -ge 90 ] && echo "WARNING" || echo "OK")" \
            "/var|$(df -h /var | tail -1 | awk '{print $5}')|$([ "$(df /var | tail -1 | awk '{print $5}' | sed 's/%//')" -ge 90 ] && echo "WARNING" || echo "OK")" \
            "Available Space|$((AVAILABLE_SPACE / 1024 / 1024))GB|CRITICAL" \
            "Required Space|10GB minimum|N/A")

        send_alert_once "backup_postgres_disk_space_low" "$ALERT_COOLDOWN" \
            "[PostgreSQL Backup] CRITICAL: Insufficient Disk Space" \
            "$disk_metrics

<p>Backup directory <strong>$BACKUP_DIR</strong> has insufficient space.</p>

<strong>Available:</strong> $((AVAILABLE_SPACE / 1024 / 1024))GB
<strong>Required:</strong> 10GB minimum
<strong>Backup Status:</strong> ABORTED" \
            "${ALERT_EMAIL:-root@localhost}" \
            "1. <strong>IMMEDIATE:</strong> Check disk usage: <code>df -h /postgresql</code>
2. Find large files: <code>sudo du -h /postgresql | sort -rh | head -20</code>
3. Check old backups: <code>ls -lht $BACKUP_DIR/ | head -20</code>
4. Clean old backups manually if needed: <code>find $BACKUP_DIR \\( -name '*.sql.gz' -o -name '*.sql.zst' \\) -mtime +7 -delete</code>
5. Check PostgreSQL WAL archives: <code>du -sh /postgresql/archive/</code>
6. Clean PostgreSQL logs: <code>sudo journalctl --vacuum-time=7d</code>
7. Re-run backup after cleanup: <code>sudo systemctl start backup-postgresql.service</code>
8. See runbook for detailed disk space management" \
            "🔴 <strong>BACKUP ABORTED!</strong>
❌ No PostgreSQL backups created today
❌ RPO at risk (last backup may be 24+ hours old)
⚠️  Database writes may fail if disk fills completely
⚠️  Immediate cleanup required before next scheduled backup (03:00)
ℹ️  Retention policy: 7 days (automatic cleanup may have failed)" \
            "<repo>/docs/operations/DISK_SPACE_MANAGEMENT.md"
        exit 1
    fi

    log_success "$LOG_PREFIX Sufficient disk space available: $((AVAILABLE_SPACE / 1024 / 1024))GB"

    # Create backup
    log_info "$LOG_PREFIX Creating backup: $BACKUP_FILE"

    if pg_dumpall > "$BACKUP_FILE" 2>> /var/log/postgresql-backup.log; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "$LOG_PREFIX Backup created successfully: $BACKUP_FILE (Size: $BACKUP_SIZE)"
    else
        log_error "$LOG_PREFIX pg_dumpall failed! Check /var/log/postgresql-backup.log"

        # Get recent errors from PostgreSQL logs (redacted for security)
        pg_errors=$(tail -20 /var/log/postgresql-backup.log 2>/dev/null || echo "Unable to read backup log")
        pg_errors=$(redact_sensitive_data "$pg_errors")

        send_alert_once "backup_postgres_dump_failed" "$ALERT_COOLDOWN" \
            "[PostgreSQL Backup] CRITICAL: pg_dumpall Error" \
            "PostgreSQL backup command <code>pg_dumpall</code> failed during execution.

<strong>Backup File:</strong> $BACKUP_FILE
<strong>Log File:</strong> /var/log/postgresql-backup.log

<strong>Recent Errors (last 20 lines):</strong>
<pre>$pg_errors</pre>" \
            "${ALERT_EMAIL:-root@localhost}" \
            "1. Check detailed backup log: <code>tail -50 /var/log/postgresql-backup.log</code>
2. Check PostgreSQL service status: <code>systemctl status postgresql</code>
3. Check PostgreSQL logs: <code>journalctl -u postgresql -n 50</code>
4. Test manual backup: <code>sudo -u postgres pg_dumpall > /tmp/test_backup.sql</code>
5. Check postgres user permissions: <code>ls -la $BACKUP_DIR</code>
6. Verify PostgreSQL is accepting connections: <code>sudo -u postgres psql -c 'SELECT version();'</code>
7. Check for connection limits: <code>sudo -u postgres psql -c 'SELECT count(*) FROM pg_stat_activity;'</code>
8. If permissions issue: <code>sudo chown postgres:postgres $BACKUP_DIR && sudo chmod 750 $BACKUP_DIR</code>
9. See runbook for PostgreSQL recovery procedures" \
            "🔴 <strong>BACKUP COMMAND FAILED!</strong>
❌ No PostgreSQL backups created
❌ RPO at risk (last backup may be 24+ hours old)
⚠️  Database may be corrupted or inaccessible
⚠️  Connection limits may be exceeded
ℹ️  Check /var/log/postgresql-backup.log for detailed error messages
ℹ️  Scheduled backup runs daily at 03:00" \
            "<repo>/docs/services/POSTGRESQL_RECOVERY.md"
        exit 1
    fi

    # Compress backup with zstd (multi-threaded, better compression)
    log_info "$LOG_PREFIX Compressing backup with zstd (4 threads)..."

    if zstd -T4 --rm -q "$BACKUP_FILE" -o "${BACKUP_FILE}.zst"; then
        COMPRESSED_SIZE=$(du -h "${BACKUP_FILE}.zst" | cut -f1)
        log_success "$LOG_PREFIX Backup compressed: ${BACKUP_FILE}.zst (Size: $COMPRESSED_SIZE)"
    else
        log_error "$LOG_PREFIX Compression failed!"
        send_alert_once "backup_postgres_compression_failed" "$ALERT_COOLDOWN" \
            "[PostgreSQL Backup] WARNING: Compression Failed" \
            "Backup created but compression failed: $BACKUP_FILE" \
            "${ALERT_EMAIL:-root@localhost}"
        # Don't exit, backup is still valid
    fi

    # Set correct permissions (already owned by postgres user)
    chmod 640 "${BACKUP_FILE}.zst" 2>/dev/null || true

    # Cleanup old backups (retention policy) - handles both .gz and .zst
    log_info "$LOG_PREFIX Applying retention policy: keeping backups from last $RETENTION_DAYS days"

    DELETED_COUNT=$(find "$BACKUP_DIR" \( -name "*.sql.gz" -o -name "*.sql.zst" \) -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)

    if [ "$DELETED_COUNT" -gt 0 ]; then
        log_info "$LOG_PREFIX Deleted $DELETED_COUNT old backup(s)"
    else
        log_info "$LOG_PREFIX No old backups to delete"
    fi

    # List current backups (count both formats)
    CURRENT_BACKUPS=$(find "$BACKUP_DIR" \( -name "*.sql.gz" -o -name "*.sql.zst" \) -type f | wc -l)
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

    log_success "$LOG_PREFIX Backup process completed successfully"
    log_info "$LOG_PREFIX Current backups: $CURRENT_BACKUPS files, Total size: $TOTAL_SIZE"

    # Optional: Send success notification (only on explicit config)
    if [ "${BACKUP_SUCCESS_NOTIFICATION:-false}" = "true" ]; then
        send_alert "PostgreSQL Backup Success" "PostgreSQL backup completed successfully. Files: $CURRENT_BACKUPS, Total: $TOTAL_SIZE" "${ALERT_EMAIL:-root@localhost}"
    fi
}

# Execute main function
main "$@"

exit 0
