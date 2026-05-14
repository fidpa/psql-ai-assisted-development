# CLAUDE.md — AI Assistant Briefing

This file is the system prompt for [Claude Code](https://www.claude.com/product/claude-code)
and any other AI assistant working inside this repository. Read it before
making changes — it is intentionally short and points at the documents that
hold the actual detail.

## 🎯 First-stop documents

For any non-trivial task, open the matching reference before writing SQL:

- **SQL syntax**: [`docs/reference/POSTGRESQL_REFERENZ.md`](docs/reference/POSTGRESQL_REFERENZ.md)
  (current) and [`docs/reference/SQL_SERVER_LEGACY.md`](docs/reference/SQL_SERVER_LEGACY.md)
  (migration history, for understanding `-- Migrated from: …` headers).
- **KPI definitions & business rules**: [`docs/explanation/PROJEKT_ARCHITEKTUR.md`](docs/explanation/PROJEKT_ARCHITEKTUR.md).
- **Power BI / DirectQuery patterns**: [`docs/how-to/POWER_BI_DASHBOARD_ENTWICKLUNG.md`](docs/how-to/POWER_BI_DASHBOARD_ENTWICKLUNG.md).
- **Daily ops**: [`docs/how-to/POSTGRESQL_DAILY_OPS.md`](docs/how-to/POSTGRESQL_DAILY_OPS.md).
- **Troubleshooting**: [`docs/how-to/TROUBLESHOOTING_DATENBANK.md`](docs/how-to/TROUBLESHOOTING_DATENBANK.md).

## 🎯 Thematic entry points

These five files are curated paths into the documentation set. Pick the one
that matches the task at hand:

- 🗄️ **[SQL & Database Development](docs/entry-points/SQL_DATABASE_DEVELOPMENT.md)** — views, KPIs, performance.
- 🔄 **[PostgreSQL Migration](docs/entry-points/POSTGRESQL_MIGRATION.md)** — how the SQL Server → PostgreSQL move was done.
- 📊 **[Power BI & Analytics](docs/entry-points/POWER_BI_ANALYTICS.md)** — dashboards, DirectQuery.
- 📝 **[Session Documentation](docs/entry-points/SESSION_DOCUMENTATION_MANAGEMENT.md)** — how the docs evolved alongside the code.
- 🔌 **[Remote Connectivity](docs/entry-points/REMOTE_MANAGEMENT_CONNECTIVITY.md)** — SSH, VPN, ops tooling.

## 🔧 Working language and house style

- **German** for business logic, view-internal comments, and explanation docs.
  The original migration was for a German-speaking team and the artefacts
  are kept that way on purpose — see the German column names in
  [`sql/views/03_kpi/vw_kpi_dashboard.sql`](sql/views/03_kpi/vw_kpi_dashboard.sql).
- **English** for the README, CHANGELOG, scripts, and any technical surface
  that an outside contributor would touch.
- **Directive voice**: "Use X" beats "X is available".

## 💻 Common commands

### psql shell

```bash
# Standard connection (replace host / db / user for your environment)
psql -h localhost -p 5432 -U postgres -d postgres

# Run a single ad-hoc query
psql -h localhost -U postgres -c "SELECT * FROM vw_kpi_dashboard_gesamt;"

# Apply a SQL file
psql -h localhost -U postgres -f sql/schemas/01_schema.sql
```

### Operational scripts

```bash
# pg_dumpall-based backup with retention
bash scripts/backup-postgres.sh

# Cache-hit-ratio and pg_stat_statements snapshot
bash scripts/monitor-postgres-performance.sh

# Cross-area validation (schema + functions + views)
bash scripts/validate-all-areas.sh
```

### View development workflow

```sql
-- 1. Pick the right layer:
--    sql/views/01_dim/  for new dimensions
--    sql/views/02_fact/ for new fact views
--    sql/views/03_kpi/  for new KPI aggregations
-- 2. Follow the existing naming convention (snake_case, vw_<layer>_<topic>)
-- 3. Add a file header with: purpose, dependencies, and any SQL-Server-to-
--    PostgreSQL migration notes (see existing files for the template).

-- KPI sanity check against an expected value
-- (replace the literal with the value from docs/explanation/PROJEKT_ARCHITEKTUR.md):
SELECT
    'e1_last_working_day' AS kpi,
    (SELECT e1_last_working_day FROM vw_kpi_dashboard_gesamt) AS calculated,
    0::INTEGER AS expected;
```

## 📁 Directory layout

```
sql/
├── schemas/      # base schema (01_schema.sql)
├── views/01_dim/ # dimensions (vw_dim_*)
├── views/02_fact/# facts (vw_fact_*)
├── views/03_kpi/ # KPI aggregations (vw_kpi_*)
├── functions/    # PL/pgSQL helpers (fn_easter_sunday, fn_working_days_between)
├── tables/       # fact_expiry_mat (MATERIALIZED VIEW),
│                 # kpi_historie (regular table; file: kpi_history.sql)
├── procedures/   # stub — not shipped, see sql/procedures/README.md
└── migrations/   # versioned migration scripts (placeholder)

config/           # postgresql.conf overrides for a 64 GB host
scripts/          # backup, performance monitor, validation, deploy helpers
docs/             # Diátaxis-structured documentation (German)
```

Convention: `.sql` is PostgreSQL. Any `.sqlserver.sql` siblings (where they
exist) are kept for historical reference only — do not run them.

Note: `sql/schemas/01_schema.sql` creates only the `order_processing`
namespace. The source-table DDL referenced below (`order_doc`, `order_line`,
`appointment`, `provider`, `customer`, `counterparty`, `invoice_insurer`,
`service_type`) is **not shipped** with the public release; point the views
at your own equivalent schema.

## 🏗️ View hierarchy (bottom-up)

```
Layer 1: Source tables — order_doc, order_line, appointment (65 M+),
                         provider, customer, counterparty,
                         invoice_insurer, service_type
   │
Layer 2: vw_dim_*       — dimension views with provider sentinel logic,
                         German holiday calendar, customer classification
   │
Layer 3: vw_fact_*      — vw_fact_order, vw_fact_order_intake,
                         vw_fact_expiry_calculation, vw_fact_expiry,
                         vw_fact_invoice_provider
   │
   ├── fact_expiry_mat  — materialised table over the 65 M+ appointment join
   │
Layer 4: vw_kpi_*       — one CTE per KPI family (E/S/D/V/C), composed by
                         vw_kpi_dashboard_gesamt into a single dashboard row
```

The full dependency graph is in the README's Architecture section. The
business rationale for each KPI is in
[`docs/explanation/PROJEKT_ARCHITEKTUR.md`](docs/explanation/PROJEKT_ARCHITEKTUR.md).

## 🧩 Core business rules

1. **Partner tier**: `provider_group_id IN (1, 2)` separates tier-A (internal)
   from tier-B (external) providers.
2. **Auto-processing routing**: an order is auto-classified when
   `service_type_id IN (10, 20, 30, 40)` AND
   `COALESCE(source_system_id, 0) > 0` AND `import_type IN (1, 2)`.
   The `COALESCE` form is the established pattern across `vw_dim_provider`
   and the `vw_kpi_order_sorting*` views — do not rewrite it as `IS NOT NULL`.
3. **Retention window**: 180 days after the last reference event. Encoded
   as `INTERVAL '180 days'` in
   [`sql/views/02_fact/vw_fact_expiry_calculation.sql`](sql/views/02_fact/vw_fact_expiry_calculation.sql)
   at six call sites — change them together (no single constant exists).
4. **Working days**: Monday–Friday minus the German national holiday set
   (movable holidays via [`fn_easter_sunday`](sql/functions/fn_easter_sunday.sql)).

## 🚨 Do's and don'ts

### ✅ Do

- **Read the file header** of any existing view before adding a new one — the
  migration notes there explain why the SQL looks the way it does.
- **Validate KPIs** against an expected value (`docs/explanation/PROJEKT_ARCHITEKTUR.md`)
  before declaring a change complete.
- **Aggregate in SQL, not in Power BI** — DirectQuery is mandatory.
- **Use the existing `vw_<layer>_<topic>` naming** — no new conventions.
- **Test against full data volumes**, not samples — the cache-hit-ratio
  monitor (`scripts/monitor-postgres-performance.sh`) will tell you whether
  your query plan actually scales.

### ❌ Don't

- **Never aggregate the `appointment` table directly** in a query path — use
  `fact_expiry_mat` or one of the `vw_fact_*` views. 65 M+ rows.
- **No undocumented changes** — every new view needs a file header.
- **No nested aggregate functions** in compatibility paths — they were a
  SQL Server portability trap and the patterns avoid them deliberately.
- **No assumption that Power BI will aggregate large result sets** — push
  every aggregation into SQL.

## 📚 Documentation map (Diátaxis)

Items not already covered under *First-stop documents* or *Thematic entry points*:

- **🎓 Tutorial**: [Migration Guide (3-week plan)](docs/tutorial/POSTGRESQL_MIGRATION_GUIDE.md) · [Migration Technical](docs/tutorial/POSTGRESQL_MIGRATION_TECHNISCH.md) · [SSH Setup Mac → Windows](docs/tutorial/SSH_SETUP_MAC_WINDOWS.md)
- **🔧 How-to**: [Automation](docs/how-to/POSTGRESQL_AUTOMATION.md) · [Task Tracking](docs/how-to/TASK_TRACKING.md) · [Session Workflow](docs/how-to/SESSION_WORKFLOW.md) · [Claude Code Automation](docs/how-to/CLAUDE_CODE_AUTOMATION.md)
- **📖 Reference**: [Power BI DAX Catalogue](docs/reference/POWER_BI_DAX_KATALOG.md) · [Postgres Tuning](docs/reference/POSTGRES_TUNING.md) · [Claude Code Conventions](docs/reference/CLAUDE_CODE_KONVENTIONEN.md) · [Quick Reference (KPI cheat sheet)](docs/reference/QUICK_REF.md)
- **💡 Explanation**: [Strategic Vision](docs/explanation/STRATEGISCHE_VISION.md) · [Migration Strategy](docs/explanation/MIGRATION_STRATEGIE.md) · [Remote Management Architecture](docs/explanation/REMOTE_MANAGEMENT_ARCHITEKTUR.md)

---

*Maintainer: [@fidpa](https://github.com/fidpa) — last reviewed 2026-05-14.*
