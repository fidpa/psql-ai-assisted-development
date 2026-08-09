# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-09

The missing components now ship. v0.1.2 made three of the four operational scripts honest about the fact that they could not run — they exited 2 and named the component they were missing. This release supplies those components: the shared shell library in `lib/` and the per-area documentation link validators. All four scripts now work on a fresh clone, with a test suite that verifies them without PostgreSQL, root, an MTA or a RAID array.

### Added

#### `lib/` — the shared shell library (690 lines across three files)

- **`lib/logging.sh`** — `log_info`, `log_success`, `log_warning`, `log_error`, the `log_warn` alias that `validate-all-areas.sh` expects, plus `html_escape` and the state-directory resolution. Log lines carry an elapsed-seconds prefix derived from the `SECONDS` builtin (no subprocess per line); `LOG_PERFORMANCE=false` turns it off.
- **`lib/utils.sh`** — `send_alert`, `send_alert_once`, `check_postgresql`, `check_raid_status`, `format_metrics_table_html`, `redact_sensitive_data`.
- **`lib/secure-file-utils.sh`** — `sfu_append_file`.
- **`lib/README.md`** documents the contract, the environment variables, the security model and the five rules any replacement implementation must observe. Those rules are not style preferences: each corresponds to a way the calling scripts break. The most consequential is that every library file must end in `return 0` — the callers source with `|| exit 2`, and the status of `source` is the status of the file's last command, so a trailing guard that happens to be false aborts the caller with a message that explains nothing.

Design decisions worth knowing about:

- **Alerts are never lost silently.** Every alert reaches stderr and `alerts.log` (mode 0600) *before* any delivery is attempted, then goes out via `sendmail -t` (HTML, `charset=UTF-8`) or, failing that, `mail -s` with the body flattened to text — `mail` sends `text/plain`, where raw markup would be unreadable. With no MTA at all, that is stated once per process rather than passed over. Delivery is wrapped in a 30-second timeout: "synchronous" must not mean "indefinite" inside a systemd timer.
- **The cooldown fails open.** No state directory, an unreadable stamp, or a stamp dated in the future (NTP correction, wrong RTC) all result in the alert being sent. Suppression only ever happens on positive evidence. Stamps live under `/var/lib/pg-toolkit` as root and `$XDG_STATE_HOME`/`$HOME/.local/state` otherwise — deliberately not `/run`, which is cleared at boot and would let a 24-hour cooldown re-fire after every restart.
- **`check_postgresql` probes `pg_isready` before `systemctl`.** On Debian and Ubuntu `postgresql.service` is a wrapper unit that stays `active (exited)` indefinitely, so `systemctl is-active postgresql` still reports success after `postgresql@16-main` has crashed — precisely the situation `backup-postgres.sh` exists to alert on.
- **`check_raid_status` returns 0 on a machine without RAID.** `/proc/mdstat` is present on virtually every Linux whether or not an array exists, so its mere presence proves nothing; the check looks for an array line. A resync on a complete bitmap and a spare marker are both healthy, not degraded.
- **`sfu_append_file` refuses to follow symlinks**, checked with `-L` on the path before the file is opened. That is the entire reason the function exists: `>>` follows symlinks and the monitor runs as root. Deliberately omitted as overhead: `flock` (a single `printf` into an `O_APPEND` descriptor is already atomic below `PIPE_BUF`), temp-file-plus-rename (breaks append semantics), and per-record `fsync`.
- **`redact_sensitive_data` HTML-escapes its output.** Escaping is required even inside `<pre>`, which changes whitespace handling but not parsing.

#### Documentation link validation

- **Five per-area validators** at `docs/<area>/validate-links.sh` (64 lines each, identical but for the area name) and **`lib/validate-links-core.sh`**, vendored from [bash-markdown-link-validator](https://github.com/fidpa/bash-markdown-link-validator) v1.2.3 (MIT, same copyright holder) so that a fresh clone needs no external dependency.
- `scripts/validate-all-areas.sh` now validates **371 links across 44 files** and reports 0 broken, 0 warnings.

Two patches were needed against the vendored library; both are marked `PATCH(psql-ai):` in the source and belong upstream:

1. **Link extraction required `.md` in the target**, which silently skipped 38 anchor-only links (`](#vision--mission)`) and every link to a non-markdown file such as `../../scripts/backup-postgres.sh`. Roughly 44 of 371 links were never examined while the report read "0 broken" — the same class of false all-clear that v0.1.2 removed from the orchestrator.
2. **`build_anchor_index()` recognised only HTML `id="..."` attributes**, not the markdown form `{#slug}`. A heading `## VISION & MISSION {#vision--mission}` produced the slug `vision-mission-vision-mission`, so the link pointing at it did not resolve.

#### Tests

- **`tests/run-lib-tests.sh`** — 62 checks, no test framework, runs as an ordinary user. Four injection points (`PG_TOOLKIT_STATE_DIR`, `PG_TOOLKIT_NOW`, `PG_TOOLKIT_MDSTAT`, `PG_TOOLKIT_NO_MTA`) replace the production environment. Fixtures: seven `/proc/mdstat` variants and a PostgreSQL error log carrying fabricated credentials.
- Every check that guards against a false all-clear is written in **both directions**: the clean tree must stay silent *and* a planted fault must be caught. The link-validator test plants a broken file link, a dead anchor and a missing non-markdown target, and asserts all three are reported while a valid anchor on the same page is not.
- New CI job `lib-tests`; the ShellCheck job now covers `scripts/`, `lib/`, `tests/` and the validators under `docs/` (13 scripts, 0 findings at `--severity=warning`, which is stricter than the CI gate's `--severity=error`).

### Fixed

- **Performance alerts went to the default recipient instead of `ALERT_EMAIL`.** `monitor-postgres-performance.sh` passed the recipient as argument 9 with an empty argument 5, while `backup-postgres.sh` — the canonical signature — passes it as argument 5. Both call sites now match; a library can only implement one order.
- **`sudo mdadm --detail` could block on a password prompt.** It runs in the RAID-degraded alert path, inside a systemd timer, so an interactive prompt would hang the unit until its timeout. Now `sudo -n`.
- **`ps aux` output went unredacted into alert mails.** Process command lines can contain `PGPASSWORD=` and similar. `$raid_status`, `$raid_detail`, `$mem_detail`, `$top_cpu_consumers` and `$top_mem_consumers` are now passed through `redact_sensitive_data`.
- **The Docker container status could contain a newline and break the metrics record.** `docker inspect -f … || echo "not_found"` is wrong when the container is absent: docker prints an empty line to stdout *and* exits non-zero, so the fallback was appended to that line and the value became two lines. The value is captured first and substituted afterwards.
- **RAID metrics were collected based on the existence of `/proc/mdstat`**, which proves nothing. The metric is now emitted only when an array line is actually present.
- **Two documentation anchors pointed at truncated slugs** and did nothing when clicked: `#part-1--configuration` for the heading `## Part 1 — Configuration Reference` in `POSTGRES_TUNING.md`, and `#postgresql-setup` for `## PostgreSQL Setup & Configuration` in `POSTGRESQL_REFERENZ.md`. Both were found by the newly complete link extraction.
- `PERF_METRICS_LOG` and `BACKUP_LOG` make the hardcoded `/var/log/...` paths overridable, so the scripts can be exercised without root.

### Changed

- README: the section formerly headed *Operational scripts: what is and is not shipped* is now *Operational scripts* and states per script what it still requires at runtime — `backup-postgres.sh` continues to need root, `pg_dumpall`, `zstd` and a writable `/postgresql/backups`, which shipping a library does not change.
- `CLAUDE.md`: directory layout extended with `lib/` and `tests/`; the description of `validate-all-areas.sh` corrected — it validates documentation links, not "schema + functions + views".

### Upgrade notes

- **If you supplied your own library via `PG_TOOLKIT_LIB_DIR`, nothing changes** — that variable still takes precedence. Read `lib/README.md` for the five rules; violating any of them makes the calling script exit 2.
- **Performance alerts now reach `ALERT_EMAIL`.** If you relied on them arriving at `root@localhost` while `ALERT_EMAIL` was set to something else, that address will start receiving them.
- **Alerts are written to `alerts.log` in the state directory** (mode 0600) in addition to being mailed. The file grows without bound and contains full alert bodies including system details — add it to your log rotation.
- **`sfu_append_file` now refuses symlinked targets.** If your metrics log is deliberately a symlink, point `PERF_METRICS_LOG` at the real path instead.

## [0.1.2] - 2026-08-09

Audit of the operational scripts against what they actually do when run. Three of the four scripts in `scripts/` could not work as shipped — they depend on components of the original server that were never published — and one of them reported success while doing nothing. Everything here is a repair or a corrected statement; no view, function, KPI definition or business rule was touched.

### Fixed

#### `validate-all-areas.sh` reported success on a run in which nothing was validated

- **The final verdict ignored the failure counter.** The script calls a per-area validator at `docs/<area>/validate-links.sh`; that validator has never been part of the public release, so all five areas aborted with exit code 127. The summary then printed `Failed: 5` and, two lines later, `✅ All links validated successfully!` and exited 0 — because the verdict looked only at the broken-link total, and a validator that never runs never finds a broken link. An area that fails to run is now a failure: exit 1 with `N of 5 areas did not run — nothing was validated there`.
- **A missing validator is now detected before the run, not after it.** The script checks up front and exits 2 with the list of expected paths and the contract a drop-in validator has to satisfy (the four aggregate lines the orchestrator parses), instead of surfacing as five bare `exit 127` lines.
- **Shebang was `#!/opt/homebrew/bin/bash`** — a macOS Homebrew path. Direct execution failed on every Linux host with `bad interpreter: No such file or directory`. Now `#!/bin/bash`, as in the other three scripts. (Invocation via `bash scripts/…`, which the documentation recommends because the files carry no executable bit, was unaffected — which is why this survived two releases.)
- Header comments translated to English and made internally consistent: the file claimed "5 areas" in one line and "6 areas" in another, and its `Version:` header said 1.0.0 while its own changelog block documented a v1.0.1.

#### The shared shell library was unreachable and undeclared

- **`backup-postgres.sh` and `monitor-postgres-performance.sh` aborted on line 25 / 28** with a raw `No such file or directory`, because both source a shared library (`logging.sh`, `utils.sh`, `secure-file-utils.sh`) that is not shipped. Both now check first and exit 2 with the list of functions they need — `log_info`, `log_warning`, `log_success`, `log_error`, `send_alert`, `send_alert_once`, `check_postgresql`, `check_raid_status`, `format_metrics_table_html`, `redact_sensitive_data`, `sfu_append_file` — and the `PG_TOOLKIT_LIB_DIR` override that points at your own implementation.
- **`backup-postgres.sh` looked for the library at `${SCRIPT_DIR}/../../../lib`** — three levels *above* the repository root, a leftover from the original directory tree. Aligned with the other script to `${SCRIPT_DIR}/../lib`.

#### `deploy.sh`

- **`psql … -f deploy.sql` was resolved against the current working directory**, so the documented invocation from the repository root (`bash scripts/deploy.sh …`) failed with a missing-file error. The path is now derived from the script location and checked before the prompt.
- User-facing output was German and the confirmation prompt accepted only `j`/`J`; an English-speaking operator answering `y` got `Abgebrochen.` Output is English now and both `y` and `j` are accepted.

#### PostgreSQL metrics failed silently in `monitor-postgres-performance.sh`

- `PGPASSWORD="${UBUNTU_POSTGRES_MONITORING_PASSWORD}"` had no default at five call sites. Under `set -u` the command substitution aborted, the trailing `|| echo` caught it, and every PostgreSQL metric — connection count, largest database, its size, cache-hit ratio — fell back to `0`/`N/A` without a word. Renamed to `PG_MONITORING_PASSWORD` with an explicit empty default and documented (see *Upgrade notes*).
- A `DISK_IO_HIGH=1000` threshold was declared in the thresholds block and evaluated nowhere. Removed rather than left standing: a threshold that nothing enforces reads like a guarantee that does not exist.
- `shellcheck --severity=warning` now reports **0 findings across all four scripts**, down from 4. Two of them (`LOG_TAG`) were false positives — the variable is read by the sourced logging library — and are now suppressed with that reason in place; the other two were the unused `DISK_IO_HIGH` and an unused `mem_free`.

#### Documentation corrected against the code

- `README.md` claimed "✅ Released as v0.1.3 (2026-05-14)" in the project-phase table. There has never been a v0.1.3 — the repository had two tags and two releases, the latest `v0.1.1`. The phase table describes phases, not versions; the version claim is gone and points at this changelog instead.
- `CLAUDE.md` described `validate-all-areas.sh` as "cross-area validation (schema + functions + views)". It validates documentation links across the five Diátaxis areas and touches no SQL at all.
- `docs/tutorial/SSH_SETUP_MAC_WINDOWS.md` showed three IPv4 addresses in an `ipconfig` sample. Two were anonymised to the `10.0.0.x` placeholder range; the third was a WSL/Hyper-V vEthernet adapter address left over from the source machine, which the anonymisation pass had missed. Pulled into the placeholder range. The forbidden-term sweep in CI could not have caught it — it checks vocabulary, not addresses.

### Changed

- **`release.yml` now builds the release body from the CHANGELOG** instead of `generate_release_notes: true`. GitHub generated those notes from commit messages, and this repository's history consists of bare `v0.1.0` / `v0.1.1` lines: the two existing releases carry **88 and 97 characters** of body — a comparison link and nothing else — while their changelog sections hold **1,654 and 2,316 characters**. The workflow now extracts the section for the pushed tag and fails the run if that section is empty, so a release with an empty body cannot be published unnoticed.
- **New README section, *Operational scripts: what is and is not shipped***, stating per script whether it runs as shipped, which external component it needs, which functions that component must provide, and which environment variables the scripts read. This follows the precedent already set for the source-table DDL and `sql/procedures/`: what is published here is the logic, not a turn-key installation.
- Tool version of `validate-all-areas.sh` raised from 1.0.0 to **1.1.0**. This counter is the script's own and has never been equal to the repository version; it is not aligned with it, deliberately — from the script's point of view that would be a downgrade.
- `.gitignore` now covers `.claude/` as a whole. `CLAUDE.md` stays tracked: it is a shipped artefact of this repository, not a local override.

### Upgrade notes

- **`UBUNTU_POSTGRES_MONITORING_PASSWORD` was renamed to `PG_MONITORING_PASSWORD`.** If you export the old name for `monitor-postgres-performance.sh`, rename it — otherwise the PostgreSQL metrics stay empty. They did so before this release as well, only without an error message; the rename is the point at which that becomes visible.
- **Three scripts now exit 2 instead of 0, 1 or a raw shell error** when their dependency is missing. If you invoke them from a timer, a wrapper or a CI job that treats any non-zero exit as an alert, the missing dependency will surface now — which is the intent. Set `PG_TOOLKIT_LIB_DIR` to your own library directory, or supply `docs/<area>/validate-links.sh`, to make them run.

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

[0.2.0]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.2.0
[0.1.2]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.2
[0.1.1]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.1
[0.1.0]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.0
