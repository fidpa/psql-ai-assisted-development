# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.3] - 2026-08-30: The dashboard names every weekday, and the README states its limits

A documentation pass over `README.md` and `CLAUDE.md` against the portfolio's
README quality standards, plus the one code defect the pass turned up. Every
claim in the README was traced to the file that backs it; three did not hold and
are corrected below. No view definition, business rule or threshold changed.

### Fixed

- **`vw_kpi_dashboard_gesamt` names Monday and Friday again.** The `wochentag`
  column matched `EXTRACT(ISODOW FROM CURRENT_DATE)` against `WHEN 10` and
  `WHEN 20`. `ISODOW` returns 1 to 7, so neither branch could ever be taken and
  the column came back `NULL` on those two days. The branches now read `WHEN 1`
  and `WHEN 5`; the other five were already correct, and no other column of the
  view is affected.

### Changed

- **Three README claims did not survive the check against the code.** The
  retention window is not configurable: `INTERVAL '180 days'` is written out at
  six call sites in `sql/views/02_fact/vw_fact_expiry_calculation.sql`, and the
  README now says so instead of promising a default that can be overridden. The
  dashboard view is 101 lines, not the "~80" the README claimed, so the line
  count is gone rather than corrected. And the holiday set in
  `sql/views/01_dim/vw_dim_working_days.sql` is German, six fixed dates and four
  derived from Easter, which the README now names instead of calling the view
  "easily adaptable to other regions".
- **The link and file counts are gone from `README.md` and `CLAUDE.md`.** Both
  stated "371 links across the 44 documentation files" next to
  `scripts/validate-all-areas.sh`. The figure was correct on the day it was
  written and drifts with every documentation commit; the script prints what it
  checked when it runs. `CLAUDE.md` keeps the counts that do not drift, and they
  were measured for this release: five Diátaxis areas carry a
  `validate-links.sh`, `lib/README.md` states five rules, and the retention
  interval has six call sites.
- **The README states what the repository is not.** A section after the feature
  list collects the limits that were previously scattered or absent: it ships no
  source tables and no sample data, so only the schema file and the standalone
  functions apply to an empty database; the refresh procedure behind
  `fact_expiry_mat` is not shipped; the figures that motivated these patterns
  (the 65 million row `appointment` table, the sub-second dashboard) describe the
  source system and cannot be reproduced from this clone; and the holiday logic,
  KPI codes and German column names carry the origin with them.
- **The project-status table is gone.** Six phases, six green checkmarks, no
  information. It is replaced by a paragraph naming what still moves
  (documentation and the operational scripts) and what does not (the SQL layer).
  The `Status` badge still anchors to that heading.
- **The README prose was rewritten where it read like a generated template.**
  The `**The Problem**:` scaffold is gone; the "What you can learn from this
  repo" list was restating six of the nine feature bullets and has been dissolved
  into them, with its migration mechanics moved next to the SQL extract; and 34
  em dashes, 18 typographic ellipses and the `©` sign are ASCII now, leaving the
  acute in "Diátaxis" as the only non-ASCII character in the file. `deploy.sh`
  gained the positional signature from its own header.

### Upgrade notes

- **Re-create `vw_kpi_dashboard_gesamt`** from
  `sql/views/03_kpi/vw_kpi_dashboard.sql` to pick up the weekday fix. Nothing
  else needs re-creating and `fact_expiry_mat` does not need re-materialising:
  the fix touches one metadata column, not a KPI value.
- **Reports that filtered or grouped on `wochentag` will see two more groups.**
  Rows produced on a Monday or Friday before this release carry `NULL` there.
  Historical KPI numbers are unchanged; only the label they were filed under is.
- **`vw_kpi_dashboard_gesamt` is a one-row view over `CURRENT_DATE`**, so there
  is nothing to backfill unless a downstream table archived the `NULL` labels.

## [0.2.2] - 2026-08-28: GitHub identifies the project as MIT-licensed

### Changed

- **The repository page shows the MIT licence, and licence-filtered searches
  find the project.** `LICENSE` carried the repository URL on its own line
  under the copyright notice. GitHub reads a licence text with an extra line as
  modified and reports `NOASSERTION`, which leaves the licence field on the
  repository page empty. The line is gone; the MIT text and the copyright
  notice are byte-for-byte unchanged, and the URL is still in `README.md`.

## [0.2.1] - 2026-08-28: Release pages carry a headline and the body of their tag

An editorial pass over this changelog and the four published release pages, against the release-message conventions this portfolio follows. Every measured value, path, function name and version number is unchanged. Where a figure was checked against the tag it describes and did not hold, the corrected value is listed below.

### Changed

- **Release titles say what a version changes** instead of repeating the tag name that GitHub already prints beside it. Each section heading carries that headline after the date (`## [0.2.0] - 2026-08-09: ...`), and `release.yml` reads it from there, so title and body come from one source.
- **Every published release shows the changelog section for its tag.** `v0.1.0` and `v0.1.1` carried the `**Full Changelog**` line that GitHub generates from commit messages, and the commit messages in this repository are bare version numbers.
- **Each entry opens with what changed for an operator**, with the cause in the sentence below it. The `[0.1.0]` and `[0.1.1]` sections had no lead sentences.
- **The changelog is plain ASCII.** Em dashes, arrows and ellipses are replaced by the punctuation or the word they stood in for. What stays are quotations and one name: the check marks inside the quoted `validate-all-areas.sh` output and the quoted README line, and the em dash inside a quoted `POSTGRES_TUNING.md` heading, because an altered quotation is not one and that dash is what produced the truncated slug it is quoted for; plus the acute in `Diátaxis`, the name of the documentation framework.
- **`release.yml` sets the release title** from the section heading and strips the leading blank line off the extracted body. Without the first, `softprops/action-gh-release` falls back to the tag name; without the second, every body it generates differs from its own section by one byte.

### Fixed

- **The body and section sizes in the `[0.1.2]` section were paired with the wrong versions.** It reads `88 and 97 characters` of release body against `1,654 and 2,316 characters` of changelog section in the same order, but `[0.1.0]` is the longer section. Measured against `v0.1.2`: `[0.1.0]` holds 2,299 characters, `[0.1.1]` holds 1,652. The earlier pair were byte counts of sections that contain multi-byte punctuation.
- **The entry on the anonymisation gap in `docs/tutorial/SSH_SETUP_MAC_WINDOWS.md` characterised what it removed.** It now states that the sample address was pulled into the placeholder range and why the forbidden-term sweep could not have caught it, without describing the value.

## [0.2.0] - 2026-08-09: All four operational scripts run on a fresh clone

The missing components now ship. v0.1.2 made three of the four operational scripts honest about the fact that they could not run: they exited 2 and named the component they were missing. This release supplies those components, the shared shell library in `lib/` and the per-area documentation link validators. All four scripts now work on a fresh clone, with a test suite that verifies them without PostgreSQL, root, an MTA or a RAID array.

### Added

#### `lib/`: the shared shell library (690 lines across three files)

- **The logging functions the sourcing scripts expect**, in `lib/logging.sh`: `log_info`, `log_success`, `log_warning`, `log_error`, the `log_warn` alias that `validate-all-areas.sh` expects, plus `html_escape` and the state-directory resolution. Log lines carry an elapsed-seconds prefix derived from the `SECONDS` builtin (no subprocess per line); `LOG_PERFORMANCE=false` turns it off.
- **The alerting, health-check and redaction helpers**, in `lib/utils.sh`: `send_alert`, `send_alert_once`, `check_postgresql`, `check_raid_status`, `format_metrics_table_html`, `redact_sensitive_data`.
- **The append helper that refuses symlinks**, in `lib/secure-file-utils.sh`: `sfu_append_file`.
- **The contract a replacement library has to meet** is written down in `lib/README.md`: the environment variables, the security model and the five rules any replacement implementation must observe. Those rules are not style preferences, because each corresponds to a way the calling scripts break. The most consequential is that every library file must end in `return 0`: the callers source with `|| exit 2`, and the status of `source` is the status of the file's last command, so a trailing guard that happens to be false aborts the caller with a message that explains nothing.

Design decisions worth knowing about:

- **Alerts are never lost silently.** Every alert reaches stderr and `alerts.log` (mode 0600) *before* any delivery is attempted, then goes out via `sendmail -t` (HTML, `charset=UTF-8`) or, failing that, `mail -s` with the body flattened to text, because `mail` sends `text/plain`, where raw markup would be unreadable. With no MTA at all, that is stated once per process rather than passed over. Delivery is wrapped in a 30-second timeout: "synchronous" must not mean "indefinite" inside a systemd timer.
- **The cooldown fails open.** No state directory, an unreadable stamp, or a stamp dated in the future (NTP correction, wrong RTC) all result in the alert being sent. Suppression only ever happens on positive evidence. Stamps live under `/var/lib/pg-toolkit` as root and `$XDG_STATE_HOME`/`$HOME/.local/state` otherwise, deliberately not `/run`, which is cleared at boot and would let a 24-hour cooldown re-fire after every restart.
- **`check_postgresql` probes `pg_isready` before `systemctl`.** On Debian and Ubuntu `postgresql.service` is a wrapper unit that stays `active (exited)` indefinitely, so `systemctl is-active postgresql` still reports success after `postgresql@16-main` has crashed, which is precisely the situation `backup-postgres.sh` exists to alert on.
- **`check_raid_status` returns 0 on a machine without RAID.** `/proc/mdstat` is present on virtually every Linux whether or not an array exists, so its mere presence proves nothing; the check looks for an array line. A resync on a complete bitmap and a spare marker are both healthy, not degraded.
- **`sfu_append_file` refuses to follow symlinks**, checked with `-L` on the path before the file is opened. That is the entire reason the function exists: `>>` follows symlinks and the monitor runs as root. Deliberately omitted as overhead: `flock` (a single `printf` into an `O_APPEND` descriptor is already atomic below `PIPE_BUF`), temp-file-plus-rename (breaks append semantics), and per-record `fsync`.
- **`redact_sensitive_data` HTML-escapes its output.** Escaping is required even inside `<pre>`, which changes whitespace handling but not parsing.

#### Documentation link validation

- **Every documentation area validates its own links.** Five per-area validators at `docs/<area>/validate-links.sh` (64 lines each, identical but for the area name) and `lib/validate-links-core.sh`, vendored from [bash-markdown-link-validator](https://github.com/fidpa/bash-markdown-link-validator) v1.2.3 (MIT, same copyright holder) so that a fresh clone needs no external dependency.
- **`scripts/validate-all-areas.sh` now covers the whole documentation set**, validating 371 links across 44 files and reporting 0 broken, 0 warnings.

Two patches were needed against the vendored library; both are marked `PATCH(psql-ai):` in the source and belong upstream:

1. **Link extraction required `.md` in the target**, which silently skipped 38 anchor-only links (`](#vision--mission)`) and every link to a non-markdown file such as `../../scripts/backup-postgres.sh`. Roughly 44 of 371 links were never examined while the report read "0 broken", the same class of false all-clear that v0.1.2 removed from the orchestrator.
2. **`build_anchor_index()` recognised only HTML `id="..."` attributes**, not the markdown form `{#slug}`. A heading `## VISION & MISSION {#vision--mission}` produced the slug `vision-mission-vision-mission`, so the link pointing at it did not resolve.

#### Tests

- **The library can be exercised without the machine it was written for.** `tests/run-lib-tests.sh` runs 62 checks with no test framework, as an ordinary user. Four injection points (`PG_TOOLKIT_STATE_DIR`, `PG_TOOLKIT_NOW`, `PG_TOOLKIT_MDSTAT`, `PG_TOOLKIT_NO_MTA`) replace the production environment. Fixtures: seven `/proc/mdstat` variants and a PostgreSQL error log carrying fabricated credentials.
- **Every check that guards against a false all-clear is written in both directions**: the clean tree must stay silent *and* a planted fault must be caught. The link-validator test plants a broken file link, a dead anchor and a missing non-markdown target, and asserts all three are reported while a valid anchor on the same page is not.
- **The CI now lints and tests what it ships.** New job `lib-tests`; the ShellCheck job covers `scripts/`, `lib/`, `tests/` and the validators under `docs/` (13 scripts, 0 findings at `--severity=warning`, which is stricter than the CI gate's `--severity=error`).

### Fixed

- **Performance alerts went to the default recipient instead of `ALERT_EMAIL`.** `monitor-postgres-performance.sh` passed the recipient as argument 9 with an empty argument 5, while `backup-postgres.sh`, the canonical signature, passes it as argument 5. Both call sites now match; a library can only implement one order.
- **`sudo mdadm --detail` could block on a password prompt.** It runs in the RAID-degraded alert path, inside a systemd timer, so an interactive prompt would hang the unit until its timeout. Now `sudo -n`.
- **`ps aux` output went unredacted into alert mails.** Process command lines can contain `PGPASSWORD=` and similar. `$raid_status`, `$raid_detail`, `$mem_detail`, `$top_cpu_consumers` and `$top_mem_consumers` are now passed through `redact_sensitive_data`.
- **The Docker container status could contain a newline and break the metrics record.** `docker inspect -f ... || echo "not_found"` is wrong when the container is absent: docker prints an empty line to stdout *and* exits non-zero, so the fallback was appended to that line and the value became two lines. The value is captured first and substituted afterwards.
- **RAID metrics were collected based on the existence of `/proc/mdstat`**, which proves nothing. The metric is now emitted only when an array line is actually present.
- **Two documentation anchors did nothing when clicked** because they pointed at truncated slugs: `#part-1--configuration` for the heading `## Part 1 — Configuration Reference` in `POSTGRES_TUNING.md`, and `#postgresql-setup` for `## PostgreSQL Setup & Configuration` in `POSTGRESQL_REFERENZ.md`. Both were found by the newly complete link extraction.
- **The two log paths can be redirected**, so the scripts can be exercised without root: `PERF_METRICS_LOG` and `BACKUP_LOG` make the hardcoded `/var/log/...` paths overridable.

### Changed

- **The README says per script what it still requires at runtime.** The section formerly headed *Operational scripts: what is and is not shipped* is now *Operational scripts*: `backup-postgres.sh` continues to need root, `pg_dumpall`, `zstd` and a writable `/postgresql/backups`, which shipping a library does not change.
- **`CLAUDE.md` describes the tree it now briefs on.** Directory layout extended with `lib/` and `tests/`; the description of `validate-all-areas.sh` corrected, since it validates documentation links, not "schema + functions + views".

### Upgrade notes

- **If you supplied your own library via `PG_TOOLKIT_LIB_DIR`, nothing changes.** That variable still takes precedence. Read `lib/README.md` for the five rules; violating any of them makes the calling script exit 2.
- **Performance alerts now reach `ALERT_EMAIL`.** If you relied on them arriving at `root@localhost` while `ALERT_EMAIL` was set to something else, that address will start receiving them.
- **Alerts are written to `alerts.log` in the state directory** (mode 0600) in addition to being mailed. The file grows without bound and contains full alert bodies including system details, so add it to your log rotation.
- **`sfu_append_file` now refuses symlinked targets.** If your metrics log is deliberately a symlink, point `PERF_METRICS_LOG` at the real path instead.

## [0.1.2] - 2026-08-09: A validation run that validated nothing no longer reports success

Audit of the operational scripts against what they actually do when run. Three of the four scripts in `scripts/` could not work as shipped, because they depend on components of the original server that were never published, and one of them reported success while doing nothing. Everything here is a repair or a corrected statement; no view, function, KPI definition or business rule was touched.

### Fixed

#### `validate-all-areas.sh` reported success on a run in which nothing was validated

- **The final verdict ignored the failure counter.** The script calls a per-area validator at `docs/<area>/validate-links.sh`; that validator has never been part of the public release, so all five areas aborted with exit code 127. The summary then printed `Failed: 5` and, two lines later, `✅ All links validated successfully!` and exited 0, because the verdict looked only at the broken-link total, and a validator that never runs never finds a broken link. An area that fails to run is now a failure: exit 1 with `N of 5 areas did not run - nothing was validated there`.
- **A missing validator is now detected before the run, not after it.** The script checks up front and exits 2 with the list of expected paths and the contract a drop-in validator has to satisfy (the four aggregate lines the orchestrator parses), instead of surfacing as five bare `exit 127` lines.
- **Direct execution failed on every Linux host** with `bad interpreter: No such file or directory`, because the shebang was `#!/opt/homebrew/bin/bash`, a macOS Homebrew path. Now `#!/bin/bash`, as in the other three scripts. (Invocation via `bash scripts/...`, which the documentation recommends because the files carry no executable bit, was unaffected, which is why this survived two releases.)
- **The header comments now agree with the script.** They were translated to English and made internally consistent: the file claimed "5 areas" in one line and "6 areas" in another, and its `Version:` header said 1.0.0 while its own changelog block documented a v1.0.1.

#### The shared shell library was unreachable and undeclared

- **`backup-postgres.sh` and `monitor-postgres-performance.sh` aborted on line 25 and line 28** with a raw `No such file or directory`, because both source a shared library (`logging.sh`, `utils.sh`, `secure-file-utils.sh`) that is not shipped. Both now check first and exit 2 with the list of functions they need, `log_info`, `log_warning`, `log_success`, `log_error`, `send_alert`, `send_alert_once`, `check_postgresql`, `check_raid_status`, `format_metrics_table_html`, `redact_sensitive_data`, `sfu_append_file`, and the `PG_TOOLKIT_LIB_DIR` override that points at your own implementation.
- **`backup-postgres.sh` looked for the library three levels above the repository root**, at `${SCRIPT_DIR}/../../../lib`, a leftover from the original directory tree. Aligned with the other script to `${SCRIPT_DIR}/../lib`.

#### `deploy.sh`

- **The documented invocation from the repository root failed with a missing-file error.** `psql ... -f deploy.sql` was resolved against the current working directory, so `bash scripts/deploy.sh ...` could not find it. The path is now derived from the script location and checked before the prompt.
- **An English-speaking operator answering `y` got `Abgebrochen.`** User-facing output was German and the confirmation prompt accepted only `j`/`J`. Output is English now and both `y` and `j` are accepted.

#### PostgreSQL metrics failed silently in `monitor-postgres-performance.sh`

- **Every PostgreSQL metric fell back to `0`/`N/A` without a word**: connection count, largest database, its size, cache-hit ratio. `PGPASSWORD="${UBUNTU_POSTGRES_MONITORING_PASSWORD}"` had no default at five call sites; under `set -u` the command substitution aborted and the trailing `|| echo` caught it. Renamed to `PG_MONITORING_PASSWORD` with an explicit empty default and documented (see *Upgrade notes*).
- **A threshold that nothing enforced is gone.** `DISK_IO_HIGH=1000` was declared in the thresholds block and evaluated nowhere. Removed rather than left standing: a threshold that nothing enforces reads like a guarantee that does not exist.
- **`shellcheck --severity=warning` now reports 0 findings across all four scripts**, down from 4. Two of them (`LOG_TAG`) were false positives, since the variable is read by the sourced logging library, and are now suppressed with that reason in place; the other two were the unused `DISK_IO_HIGH` and an unused `mem_free`.

#### Documentation corrected against the code

- **The README claimed a version that never existed.** It read "✅ Released as v0.1.3 (2026-05-14)" in the project-phase table, while the repository had two tags and two releases, the latest `v0.1.1`. The phase table describes phases, not versions; the version claim is gone and points at this changelog instead.
- **`CLAUDE.md` described `validate-all-areas.sh` as "cross-area validation (schema + functions + views)".** It validates documentation links across the five Diátaxis areas and touches no SQL at all.
- **An `ipconfig` sample in `docs/tutorial/SSH_SETUP_MAC_WINDOWS.md` was outside the placeholder range.** The anonymisation pass had reached two of its three addresses; the third is now in the range as well. The forbidden-term sweep in CI could not have caught it, because it checks vocabulary, not addresses.

### Changed

- **`release.yml` now builds the release body from the CHANGELOG** instead of `generate_release_notes: true`. GitHub generated those notes from commit messages, and this repository's history consists of bare `v0.1.0` / `v0.1.1` lines: the two existing releases carry 88 and 97 characters of body, a comparison link and nothing else, while their changelog sections held 2,299 and 1,652 characters at that point. The workflow now extracts the section for the pushed tag and fails the run if that section is empty, so a release with an empty body cannot be published unnoticed.
- **The README states per script what is and is not shipped.** New section *Operational scripts: what is and is not shipped*, saying whether each script runs as shipped, which external component it needs, which functions that component must provide, and which environment variables the scripts read. This follows the precedent already set for the source-table DDL and `sql/procedures/`: what is published here is the logic, not a turn-key installation.
- **The tool version of `validate-all-areas.sh` moved from 1.0.0 to 1.1.0.** This counter is the script's own and has never been equal to the repository version; it is not aligned with it, deliberately, since from the script's point of view that would be a downgrade.
- **`.gitignore` now covers `.claude/` as a whole.** `CLAUDE.md` stays tracked: it is a shipped artefact of this repository, not a local override.

### Upgrade notes

- **`UBUNTU_POSTGRES_MONITORING_PASSWORD` was renamed to `PG_MONITORING_PASSWORD`.** If you export the old name for `monitor-postgres-performance.sh`, rename it, otherwise the PostgreSQL metrics stay empty. They did so before this release as well, only without an error message; the rename is the point at which that becomes visible.
- **Three scripts now exit 2 instead of 0, 1 or a raw shell error** when their dependency is missing. If you invoke them from a timer, a wrapper or a CI job that treats any non-zero exit as an alert, the missing dependency will surface now, which is the intent. Set `PG_TOOLKIT_LIB_DIR` to your own library directory, or supply `docs/<area>/validate-links.sh`, to make them run.

## [0.1.1] - 2026-05-14: CLAUDE.md audited against the code it briefs on

Documentation audit pass against Anthropic's CLAUDE.md best-practices (memory + best-practices guidance). Scope: `CLAUDE.md` only.

### Changed

- **`CLAUDE.md` fits within the 200-line guidance threshold**, slimmed from 207 to 191 lines and de-duplicated against the *First-stop documents* and *Thematic entry points* sections.
- **The documented script invocations work as written.** Operational-script calls in `CLAUDE.md` are now `bash scripts/...`, because the shipped scripts do not have the executable bit and `./scripts/...` would fail with `Permission denied`.
- **What the schema file creates is stated exactly.** `sql/schemas/01_schema.sql` creates only the `order_processing` namespace; source-table DDL (`order_doc`, `order_line`, `appointment` and the rest) is not shipped with the public release.

### Fixed

- **Every AI session was briefed with pre-migration content that contradicted the rest of the file.** The `@./docs/imports/QUICK_REF.md` import injected Windows `psql.exe`, a non-existent `vw_PowerBI_*` layer and "SQL Server Express (aktuell)"; the import is removed.
- **The KPI sanity-check SQL example is copy-paste runnable.** The `<EXPECTED_VALUE>` placeholder is replaced by a typed literal with an explanatory comment.
- **The `tables/` directory comment names the right object types.** It labels `fact_expiry_mat` as `MATERIALIZED VIEW` and notes that the trend-history table identifier is `kpi_historie` (the file is `kpi_history.sql`).
- **The documented auto-processing routing rule matches the codebase pattern**, `COALESCE(source_system_id, 0) > 0` rather than `IS NOT NULL`.
- **The retention window is described as the six call sites it is.** `INTERVAL '180 days'` appears six times in `vw_fact_expiry_calculation.sql`, not as a single constant.

## [0.1.0] - 2026-05-14: Initial public release of the anonymised view layer

Initial public release.

### Added

- **Repository scaffolding**: `LICENSE`, `.gitignore`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`.
- **GitHub Actions workflows**: `lint.yml` (ShellCheck, SQLFluff, markdownlint, anonymisation guardrail with base64-obfuscated forbidden-term list) and `release.yml` (automatic GitHub Release on tag push).
- **SQL lint configuration** in [`.sqlfluff`](.sqlfluff), excluding the rule groups that conflict with the chosen view-layer conventions (`aliasing`, `capitalisation`, `layout`, `references`, `structure`) while keeping parsing, ambiguity, and convention checks active.
- **Anonymised SQL**: star-schema dimensions (`vw_dim_*`), fact views (`vw_fact_*`), KPI aggregations (`vw_kpi_*`), helper functions (`fn_easter_sunday`, `fn_working_days_between`), materialised expiry table (`fact_expiry_mat`), KPI history table.
- **Diátaxis documentation set**: tutorial, how-to, reference, explanation and entry-points, 44 Markdown files, German.
- **PostgreSQL tuning configuration** in [`config/postgres-tuning-64gb.conf`](config/postgres-tuning-64gb.conf): a 64 GB NVMe baseline with documented rationale per override.
- **Operational scripts**: `backup-postgres.sh` (`pg_dumpall` with retention), `monitor-postgres-performance.sh` (cache-hit-ratio + `pg_stat_statements`), `validate-all-areas.sh` (cross-area validation), `deploy.sh` / `deploy.sql`.
- **AI-workflow blueprint** in [`CLAUDE.md`](CLAUDE.md), with [`docs/imports/QUICK_REF.md`](docs/imports/QUICK_REF.md).
- **Repository-internal anonymisation pipeline** (gitignored; `scripts/_internal/anonymize.sh`) with seven substitution passes: domain substantives, workflow steps, brand names, German columns, server and credential masking, numeric business-rule IDs, conceptual generalisation.

### Notes

- Source-table DDL is intentionally not shipped: the repository documents the view layer and conventions, not a self-contained runnable demo. Wire the views to your own schema or treat them as migration templates.
- `sql/procedures/` is intentionally empty, because refresh and health-check procedures were considered too environment-specific to generalise. See [`sql/procedures/README.md`](sql/procedures/README.md) for portable re-implementation hints.
- The retention window is parameterised (default 180 days), not a domain-specific deadline.

[0.2.3]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.2.3
[0.2.2]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.2.2
[0.2.1]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.2.1
[0.2.0]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.2.0
[0.1.2]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.2
[0.1.1]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.1
[0.1.0]: https://github.com/fidpa/psql-ai-assisted-development/releases/tag/v0.1.0
