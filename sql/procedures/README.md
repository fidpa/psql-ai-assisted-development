# PostgreSQL Stored Procedures

This directory is intentionally empty in the public release.

The source project used PostgreSQL stored procedures for materialised-view
refresh and daily health checks. They were considered too environment-specific
(scheduling, alerting, on-call hooks) to generalise without inventing fiction,
so the public repository ships **only the data layer** — tables, views, and
functions.

If you wire this codebase to your own schema, two procedures are likely
worth re-implementing:

- **`sp_aktualisiere_expiry_mat`** — incremental refresh of
  [`fact_expiry_mat`](../tables/fact_expiry_mat.sql). The simplest portable
  version is `REFRESH MATERIALIZED VIEW CONCURRENTLY fact_expiry_mat;` on a
  cron; the original tracked changed `order_id`s in a queue table and merged
  only those rows.
- **`sp_daily_health_check`** — runs the queries in
  [`scripts/monitor-postgres-performance.sh`](../../scripts/monitor-postgres-performance.sh)
  inside the database and returns a single row of green/yellow/red flags.

Pull requests adding generalised implementations of either are welcome.
