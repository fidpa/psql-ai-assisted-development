# PostgreSQL AI-Assisted Development

[![CI](https://github.com/fidpa/psql-ai-assisted-development/actions/workflows/lint.yml/badge.svg)](https://github.com/fidpa/psql-ai-assisted-development/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/fidpa/psql-ai-assisted-development)](https://github.com/fidpa/psql-ai-assisted-development/releases)
![PostgreSQL: 16+](https://img.shields.io/badge/PostgreSQL-16%2B-336791.svg?logo=postgresql&logoColor=white)
![Bash: 5+](https://img.shields.io/badge/Bash-5%2B-blue?logo=gnu-bash)
[![Built with: Claude Code](https://img.shields.io/badge/Built%20with-Claude%20Code-d97757.svg)](https://www.claude.com/product/claude-code)
[![Status](https://img.shields.io/badge/Status-Showcase-blue.svg)](#project-status)
[![Last Commit](https://img.shields.io/github/last-commit/fidpa/psql-ai-assisted-development)](https://github.com/fidpa/psql-ai-assisted-development/commits/main)

A reference implementation for AI-assisted PostgreSQL development: star-schema KPI
views, an incremental materialised view, working-day arithmetic with movable
holidays, a 64 GB tuning config, and a Claude Code workflow blueprint, documented
in Diátaxis style.

Most writing about "AI-assisted development" shows a chat transcript. This
repository shows the other half: what a database codebase looks like after an AI
assistant has been a collaborator on it for months. Not the prompts, the
artefacts.

The code was extracted from a production migration off a SQL Server Express
instance capped at 1 GB of RAM onto PostgreSQL 16 on a 64 GB host. The source
domain has been replaced with a generic document-processing and order-tracking
schema; identifiers, comments, and KPI codes were re-generated. The patterns are
preserved as they were written and transfer to any multi-stage back-office
workflow: insurance-claim handling, legal-document review, logistics returns.

## Features

- **Star-schema views**: `vw_dim_*`, `vw_fact_*`, `vw_kpi_*` with consistent
  prefixing and a documented dependency graph.
- **Incremental materialised view**: the [`fact_expiry_mat`](sql/tables/fact_expiry_mat.sql)
  table plus its index strategy, the pattern that kept expiry calculations off
  the critical path without locking out readers.
- **Working-day arithmetic**: business-day math in pure SQL, including movable
  holidays derived from Easter. The holiday set in
  [`vw_dim_working_days`](sql/views/01_dim/vw_dim_working_days.sql) is German:
  six fixed dates and four Easter-derived ones, in a single CTE that another
  region replaces wholesale.
- **Multi-stage workflow KPIs**: intake, classification, digitisation,
  registration, retention, each stage expressed as its own KPI family. Retention
  uses a fixed 180-day window, written as `INTERVAL '180 days'` in
  [`vw_fact_expiry_calculation`](sql/views/02_fact/vw_fact_expiry_calculation.sql).
- **PostgreSQL tuning config**: [`postgresql.conf` overrides](config/postgres-tuning-64gb.conf)
  for a 64 GB NVMe host, with the *why* next to every override, a
  [deployment guide](docs/reference/POSTGRES_TUNING.md), and verification queries.
- **Operational scripts**: [`pg_dumpall`-based backup with retention](scripts/backup-postgres.sh),
  a [cache-hit-ratio and `pg_stat_statements` performance monitor](scripts/monitor-postgres-performance.sh),
  and the [shared shell library](lib/) behind them: logging, cooldown-deduplicated
  alerting, RAID and PostgreSQL health checks, credential redaction. See
  [*Operational scripts*](#operational-scripts) for what each one needs to run.
- **Documentation link validation**: [`validate-all-areas.sh`](scripts/validate-all-areas.sh)
  checks every link in the documentation, anchors included, and fails the build
  on a broken one. It prints the current file and link counts when it runs.
- **Diátaxis documentation**: tutorial, how-to, reference, explanation. Four
  entry points for four kinds of reader.
- **Claude Code workflow blueprint**: a [`CLAUDE.md`](CLAUDE.md) that doubles
  as a system prompt and a navigation map.
- **CI guardrails**: an anonymisation sweep over a base64-encoded forbidden-term
  list, plus `sqlfluff`, `shellcheck`, and `markdownlint`, in
  [`.github/workflows/lint.yml`](.github/workflows/lint.yml). Every PR is checked
  before merge, so the anonymised state cannot regress over time.

## What this repository is not

- **Not a runnable demo.** It ships views, functions, and two table definitions.
  The source tables (`order_doc`, `order_line`, `appointment`, `provider`,
  `customer`, `counterparty`, `invoice_insurer`, `service_type`) are deliberately
  absent, and so is any sample data. Wire the views to your own schema, or read
  the file headers as a migration guide. Only the schema file and the standalone
  helper functions apply cleanly to an empty database.
- **Not the whole original system.** The refresh procedure behind the
  materialised expiry table (`sp_aktualisiere_expiry_mat`) is not shipped. Wire
  your own scheduled `REFRESH MATERIALIZED VIEW CONCURRENTLY` or a trigger-based
  incremental refresh against the table definition.
- **Not benchmarked here.** The figures that motivated these patterns come from
  the source system, not from anything you can measure in this clone: the
  `appointment` table held over 65 million rows, as the header of
  [`vw_fact_expiry_calculation`](sql/views/02_fact/vw_fact_expiry_calculation.sql)
  records, and the dashboard answered in seconds against the materialised table.
  Neither number is reproducible without the data.
- **Not a tutorial on prompting.** [`CLAUDE.md`](CLAUDE.md) is the artefact on
  offer, not a prompt library.
- **Not region-neutral.** Holiday logic, KPI codes, and the German column names
  carry the origin with them. That is deliberate (see
  [*Proof of substance*](#proof-of-substance-a-kpi-view)), but it is work for
  anyone adopting the views elsewhere.

---

## Architecture

```mermaid
flowchart TB
    subgraph L1[Layer 1 - Source tables]
        T1[order_doc]
        T2[order_line]
        T3[appointment 65M+ rows]
        T4[provider / customer / counterparty]
        T5[invoice_insurer / service_type]
    end

    subgraph L2[Layer 2 - Dimensions vw_dim_*]
        D1[vw_dim_provider]
        D2[vw_dim_customer]
        D3[vw_dim_working_days]
        D4[vw_dim_service_type]
        D5[vw_dim_invoice_insurer]
    end

    subgraph L3[Layer 3 - Facts vw_fact_*]
        F1[vw_fact_order]
        F2[vw_fact_order_intake]
        F3[vw_fact_expiry_calculation]
        F4[vw_fact_expiry]
        F5[vw_fact_invoice_provider]
        F6[fact_expiry_mat materialised]
    end

    subgraph L4[Layer 4 - KPI aggregations vw_kpi_*]
        K1[vw_kpi_order_intake_kpis]
        K2[vw_kpi_scanning_aggregated]
        K3[vw_kpi_capture_aggregated]
        K4[vw_kpi_expiry]
        K4b[vw_kpi_expiry_detail]
        K5[vw_kpi_controlling]
        K6[vw_kpi_capture_status_complete]
        K7[vw_kpi_order_sorting]
        K7b[vw_kpi_order_sorting_basis]
        K8[vw_kpi_dashboard_gesamt one-row summary]
    end

    L1 --> L2
    L2 --> L3
    L3 --> L4
    F3 --> F6
    F6 --> F4
    F4 --> K4
    K1 --> K8
    K2 --> K8
    K3 --> K8
    K4 --> K8
    K5 --> K8
    K7b --> K7
```

BI consumers (Power BI, in the source project) read only from the top layer, so
no analytical logic leaks down into the source tables.
[`docs/explanation/PROJEKT_ARCHITEKTUR.md`](docs/explanation/PROJEKT_ARCHITEKTUR.md)
carries the full rationale.

---

## Proof of substance: a KPI view

The names are the anonymised part. The code is not. What follows is an abridged
extract from [`sql/views/03_kpi/vw_kpi_dashboard.sql`](sql/views/03_kpi/vw_kpi_dashboard.sql),
which keeps the original German column names from the migration as a deliberate
artefact:

```sql
-- vw_kpi_dashboard_gesamt combines all KPI families into a single
-- dashboard row. Reads from five upstream KPI views, materialises one
-- row per call.
CREATE OR REPLACE VIEW vw_kpi_dashboard_gesamt AS
WITH e_werte AS (
    SELECT e1_vorheriger_tag AS e1, e2_letzte_3_tage AS e2
    FROM vw_kpi_order_intake_kpis
    WHERE e1_vorheriger_tag IS NOT NULL
    ORDER BY datum DESC
    LIMIT 1
),
s_werte AS (SELECT * FROM vw_kpi_scanning_aggregated),
d_werte AS (SELECT * FROM vw_kpi_capture_aggregated),
v_werte AS (SELECT * FROM vw_kpi_expiry),
c_werte AS (
    SELECT c1_nettosumme_unbestaetigte_kr AS c1,
           c2_count_unbestaetigte_kr      AS c2
    FROM vw_kpi_controlling
)
SELECT
    CURRENT_DATE AS datum,
    -- [...] weekday name + DD.MM.YYYY formatting omitted for brevity
    COALESCE(e.e1, 0) AS e1_last_working_day,        -- intake
    COALESCE(s.s1_naechste_3_tage, 0) AS s1_naechste_3_tage,  -- scanning
    COALESCE(d.d0_heute, 0) AS d0_heute,             -- capture today
    COALESCE(v.expiringe_vo_gesamt, 0) AS expiringe_vo_gesamt,  -- retention
    COALESCE(c.c1, 0) AS c1_nettosumme_unbestaetigte_kr  -- controlling
    -- [...] further columns omitted
FROM (SELECT 1 AS dummy) base
LEFT JOIN e_werte e ON TRUE
LEFT JOIN s_werte s ON TRUE
LEFT JOIN d_werte d ON TRUE
LEFT JOIN v_werte v ON TRUE
LEFT JOIN c_werte c ON TRUE;
```

Patterns visible at a glance:

- **One CTE per KPI family.** The alphabetic codes (`E`/`S`/`D`/`V`/`C`)
  isolate each business question, so a change in scanning logic cannot leak
  into expiry KPIs.
- **`ORDER BY ... LIMIT 1`** is the chosen pattern for "give me the latest
  value" inside a one-row dashboard view, instead of `MAX()` over the full
  history. It yields a cheaper plan on materialised upstreams.
- **`LEFT JOIN ON TRUE` against a one-row base** produces exactly one row
  even when some CTE returns zero rows, so the dashboard never goes blank.
- **`COALESCE`-wrapping** every value at the outer layer means Power BI
  visuals see numeric zeros instead of nulls.
- **No analytics in the view.** The view *composes*, the upstreams aggregate.
  This keeps DirectQuery plans flat and readable.

The view headers document the SQL Server dialect shifts per file:
`GETDATE() -> CURRENT_DATE`, `DATEADD -> INTERVAL`,
`RIGHT('0...' + CAST) -> LPAD`, `+ as concat -> ||`, and the rest.

---

## Quick Start

```bash
git clone https://github.com/fidpa/psql-ai-assisted-development.git
cd psql-ai-assisted-development

# Start a throwaway PostgreSQL
docker run --rm -d --name showcase-pg \
    -e POSTGRES_PASSWORD=showcase \
    -p 5432:5432 postgres:16

# Apply schema + standalone helper functions (always works out-of-the-box)
export PGPASSWORD=showcase
psql -h localhost -U postgres -f sql/schemas/01_schema.sql
psql -h localhost -U postgres -f sql/functions/fn_easter_sunday.sql

# Sanity check
psql -h localhost -U postgres -c "SELECT fn_easter_sunday(2026);"
#  fn_easter_sunday
# ------------------
#  2026-04-05
```

The views themselves need source tables this repository does not ship; see
[*What this repository is not*](#what-this-repository-is-not).

For production deployment, read [`docs/reference/POSTGRES_TUNING.md`](docs/reference/POSTGRES_TUNING.md):
`shared_buffers`, `effective_cache_size`, `pg_hba.conf` templates, and
verification queries for a 64 GB NVMe host.

---

## Operational scripts

Everything the scripts depend on inside the repository is here: the shared shell
library in [`lib/`](lib/) and the per-area documentation link validators. What
each script still needs is its runtime environment, a running PostgreSQL, root
privileges, a writable backup directory. That is stated per script rather than
papered over.

| Script | Runs on a fresh clone? | Still requires |
|--------|------------------------|----------------|
| [`deploy.sh`](scripts/deploy.sh) | **yes** | `psql` on `PATH`, a reachable database |
| [`validate-all-areas.sh`](scripts/validate-all-areas.sh) | **yes** | nothing |
| [`monitor-postgres-performance.sh`](scripts/monitor-postgres-performance.sh) | **yes** | a writable metrics log (`PERF_METRICS_LOG`); PostgreSQL metrics need a reachable server and `PG_MONITORING_PASSWORD` |
| [`backup-postgres.sh`](scripts/backup-postgres.sh) | partly | root, `pg_dumpall`, `zstd`, a writable `/postgresql/backups` |

`deploy.sh` takes positional arguments, as its own header states:

```text
./deploy.sh [database] [host] [port] [user]
```

with the defaults `order_processing localhost 5432 postgres`.

Try the rest without touching anything system-wide:

```bash
bash scripts/validate-all-areas.sh                       # validates every doc link
PERF_METRICS_LOG=/tmp/metrics.log \
  bash scripts/monitor-postgres-performance.sh           # writes one metrics record
bash tests/run-lib-tests.sh                              # the library test suite
```

**Replacing the library.** Point `PG_TOOLKIT_LIB_DIR` at your own implementation
of the functions listed in [`lib/README.md`](lib/README.md), which also documents
the five rules a replacement has to observe (`return 0` at the end of each file,
no assignments to the callers' readonly names, no traps, and so on):

```bash
PG_TOOLKIT_LIB_DIR=/opt/mytools/lib bash scripts/backup-postgres.sh
```

**Alert delivery** goes to stderr and to `alerts.log` in the state directory
first, and only then to an MTA (`sendmail -t`, else `mail -s`). If no MTA is
available the scripts say so once instead of losing the alert. `send_alert_once`
deduplicates by key within a cooldown window; the stamps live next to that log.
Cooldown fails open: with no usable state directory, the alert goes out anyway.
That is a delivery guarantee, not a security boundary, and
[`SECURITY.md`](SECURITY.md) carries the reporting policy.

**Environment variables** read by the scripts (the library adds more, see
[`lib/README.md`](lib/README.md)):

| Variable | Default | Used by |
|----------|---------|---------|
| `PG_TOOLKIT_LIB_DIR` | `scripts/../lib` | backup, monitor |
| `PG_TOOLKIT_STATE_DIR` | `/var/lib/pg-toolkit` as root, else `$XDG_STATE_HOME`/`$HOME/.local/state` | backup, monitor |
| `PG_MONITORING_PASSWORD` | *(empty)* | monitor, password for the read-only `monitoring` role |
| `PERF_METRICS_LOG` | `/var/log/performance-metrics.log` | monitor |
| `PERF_ALERT_HIGH_LOAD` | `true` | monitor |
| `BACKUP_LOG` | `/var/log/postgresql-backup.log` | backup |
| `BACKUP_SUCCESS_NOTIFICATION` | `false` | backup |
| `ALERT_EMAIL` | `root@localhost` | backup, monitor |

**The documentation link validators** live at `docs/<area>/validate-links.sh`,
one per Diátaxis area, driven by
[`scripts/validate-all-areas.sh`](scripts/validate-all-areas.sh). The work is
done by [`lib/validate-links-core.sh`](lib/validate-links-core.sh), vendored from
[bash-markdown-link-validator](https://github.com/fidpa/bash-markdown-link-validator).

---

## Repository Tour

| Path | Read this if you want to ... |
|------|------------------------------|
| [`CLAUDE.md`](CLAUDE.md) | ... see the workflow manifest that drives day-to-day work |
| [`docs/tutorial/`](docs/tutorial/) | ... walk through the migration from scratch |
| [`docs/how-to/`](docs/how-to/) | ... solve a specific operational task (daily ops, troubleshooting) |
| [`docs/reference/`](docs/reference/) | ... look up syntax, parameters, KPI definitions, tuning |
| [`docs/explanation/`](docs/explanation/) | ... understand *why* decisions were made |
| [`docs/entry-points/`](docs/entry-points/) | ... give Claude Code a thematic starting point |
| [`sql/views/01_dim/`](sql/views/01_dim/) | ... see the dimension views (star schema base) |
| [`sql/views/02_fact/`](sql/views/02_fact/) | ... see fact views built on dimensions |
| [`sql/views/03_kpi/`](sql/views/03_kpi/) | ... see KPI aggregations on top of facts |
| [`sql/functions/`](sql/functions/) | ... reuse working-day and holiday helpers |
| [`sql/tables/`](sql/tables/) | ... see the materialised expiry table pattern |
| [`config/`](config/) | ... grab a tuned `postgresql.conf` for a 64 GB host |
| [`scripts/`](scripts/) | ... deploy, validate, back up, monitor |
| [`lib/`](lib/) | ... see the shared shell library and the contract it fulfils |
| [`tests/`](tests/) | ... run the library test suite without PostgreSQL or root |

---

## The Claude Code workflow

Open [`CLAUDE.md`](CLAUDE.md) first. It is the single source of truth for how an
AI assistant should navigate this codebase: which files to consult first, which
conventions to follow, which traps to avoid. A project-level system prompt of
that shape is the thing this repository is actually demonstrating.

It is kept in German on purpose. The README and the SQL are English; a
domain-specific assistant brief can live in the working language of the people
who wrote it.

---

## Project status

A showcase, not a product. The extraction, anonymisation, tuning integration, and
documentation are finished, and released versions are listed in
[CHANGELOG.md](CHANGELOG.md). What still moves is documentation and the
operational scripts; the SQL layer is a snapshot and is not expected to grow.

Issues and pull requests are welcome, in particular corrections to the migration
notes. [CONTRIBUTING.md](CONTRIBUTING.md) has the details, and
[SECURITY.md](SECURITY.md) the reporting path.

---

## Requirements

- PostgreSQL 16 or newer
- `psql` client
- Bash 5+ (for the operational scripts)
- Optional: `sqlfluff`, `shellcheck`, `markdownlint-cli` for local linting
- Optional: [Claude Code](https://www.claude.com/product/claude-code) for the
  full workflow

---

## License

[MIT](LICENSE) (c) 2026 Marc Allgeier ([@fidpa](https://github.com/fidpa))

---

## See Also

Other showcase repositories in the same series:

- [`bash-production-toolkit`](https://github.com/fidpa/bash-production-toolkit), production-grade Bash patterns
- [`linux-monitoring-templates`](https://github.com/fidpa/linux-monitoring-templates), monitoring building blocks
- [`ubuntu-server-security`](https://github.com/fidpa/ubuntu-server-security), host hardening
- [`bash-markdown-link-validator`](https://github.com/fidpa/bash-markdown-link-validator), vendored here to keep this repo's docs honest

---

*Anonymised from a real production migration. The patterns are real; the
domain has been generalised.*
