# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-05-14

Documentation audit pass against Anthropic's CLAUDE.md best-practices (memory + best-practices guidance). Scope: `CLAUDE.md` only.

### Changed

- `CLAUDE.md` slimmed from 207 to 191 lines (below the 200-line guidance threshold) and de-duplicated against the *First-stop documents* and *Thematic entry points* sections.
- Operational-script invocations in `CLAUDE.md` rewritten as `bash scripts/...` (the shipped scripts do not have the executable bit, so `./scripts/...` would fail with `Permission denied`).
- Source-table availability clarified: `sql/schemas/01_schema.sql` creates only the `order_processing` namespace; source-table DDL (`order_doc`, `order_line`, `appointment`, …) is not shipped with the public release.

### Fixed

- Removed the `@./docs/imports/QUICK_REF.md` import, which injected pre-migration content (Windows `psql.exe`, non-existent `vw_PowerBI_*` layer, "SQL Server Express (aktuell)") into every AI session and contradicted the rest of the briefing.
- KPI sanity-check SQL example in `CLAUDE.md` is now copy-paste runnable (`<EXPECTED_VALUE>` placeholder replaced by a typed literal with an explanatory comment).
- `tables/` directory comment in `CLAUDE.md` correctly labels `fact_expiry_mat` as `MATERIALIZED VIEW` and notes that the trend-history table identifier is `kpi_historie` (the file is `kpi_history.sql`).
- Auto-processing routing rule in `CLAUDE.md` matches the codebase pattern: `COALESCE(source_system_id, 0) > 0` (not `IS NOT NULL`).
- Retention-window description in `CLAUDE.md` reflects that `INTERVAL '180 days'` appears at six call sites in `vw_fact_expiry_calculation.sql`, not a single constant.

## [0.1.0] - 2026-05-14

Initial public release.

### Added

- Repository scaffolding: `LICENSE`, `.gitignore`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`.
- GitHub Actions workflows: `lint.yml` (ShellCheck, SQLFluff, markdownlint, anonymisation guardrail with base64-obfuscated forbidden-term list) and `release.yml` (automatic GitHub Release on tag push).
- [`.sqlfluff`](.sqlfluff) configuration that excludes the rule groups conflicting with the chosen view-layer conventions (`aliasing`, `capitalisation`, `layout`, `references`, `structure`) while keeping parsing, ambiguity, and convention checks active.
- Anonymised SQL: star-schema dimensions (`vw_dim_*`), fact views (`vw_fact_*`), KPI aggregations (`vw_kpi_*`), helper functions (`fn_easter_sunday`, `fn_working_days_between`), materialised expiry table (`fact_expiry_mat`), KPI history table.
- Diátaxis documentation set: tutorial / how-to / reference / explanation / entry-points (44 Markdown files, German).
- PostgreSQL tuning configuration: [`config/postgres-tuning-64gb.conf`](config/postgres-tuning-64gb.conf) — 64 GB NVMe baseline with documented rationale per override.
- Operational scripts: `backup-postgres.sh` (`pg_dumpall` with retention), `monitor-postgres-performance.sh` (cache-hit-ratio + `pg_stat_statements`), `validate-all-areas.sh` (cross-area validation), `deploy.sh` / `deploy.sql`.
- [`CLAUDE.md`](CLAUDE.md) AI-workflow blueprint and [`docs/imports/QUICK_REF.md`](docs/imports/QUICK_REF.md).
- Repository-internal anonymisation pipeline (gitignored; `scripts/_internal/anonymize.sh`) with seven substitution passes: domain substantives → workflow steps → brand names → German columns → server/credential masking → numeric business-rule IDs → conceptual generalisation.

### Notes

- Source-table DDL is intentionally not shipped: the repository documents the view layer and conventions, not a self-contained runnable demo. Wire the views to your own schema or treat them as migration templates.
- `sql/procedures/` is intentionally empty — refresh and health-check procedures were considered too environment-specific to generalise. See [`sql/procedures/README.md`](sql/procedures/README.md) for portable re-implementation hints.
- The retention window is parameterised (default 180 days), not a domain-specific deadline.

[0.1.1]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.1
[0.1.0]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.0
