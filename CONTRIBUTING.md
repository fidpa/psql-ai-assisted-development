# Contributing to psql-ai-assisted-development

Thank you for your interest! This repository is a **reference implementation**
(showcase mode) — feature requests are welcome as discussions, but the primary
purpose is to preserve a documented set of patterns, not to evolve into a
generic library.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [What kinds of contributions are welcome?](#what-kinds-of-contributions-are-welcome)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Anonymisation Guardrail](#anonymisation-guardrail)

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

---

## What kinds of contributions are welcome?

| Type | Welcome? | Notes |
|------|----------|-------|
| Bug fixes (SQL syntax, broken examples) | Yes | Small PRs preferred |
| Security fixes | Yes | See [SECURITY.md](SECURITY.md) |
| Documentation clarifications | Yes | Especially Diátaxis quadrant fixes |
| New SQL patterns / view families | Discuss first | Open an issue — does it fit the showcase scope? |
| Refactoring for "cleaner code" | Discuss first | The patterns reflect a real system; cosmetic-only changes are usually declined |
| Translations | Discuss first | README is English; `docs/` and `CLAUDE.md` are German on purpose |

---

## Development Setup

### Prerequisites

- PostgreSQL 16 or newer (Docker is fine)
- `psql` client
- Bash 5+
- `sqlfluff` (lint), `shellcheck`, `markdownlint-cli` (optional but recommended)
- `git`

### Quick Start

```bash
git clone https://github.com/fidpa/psql-ai-assisted-development.git
cd psql-ai-assisted-development

# Spin up a throwaway PostgreSQL
docker run --rm -d --name showcase-pg \
    -e POSTGRES_PASSWORD=showcase \
    -p 5432:5432 postgres:16

# Apply schema and views
PGPASSWORD=showcase psql -h localhost -U postgres -f sql/schemas/01_init.sql
PGPASSWORD=showcase psql -h localhost -U postgres -f sql/functions/*.sql
PGPASSWORD=showcase psql -h localhost -U postgres -f sql/views/01_dim/*.sql
PGPASSWORD=showcase psql -h localhost -U postgres -f sql/views/02_fact/*.sql
PGPASSWORD=showcase psql -h localhost -U postgres -f sql/views/03_kpi/*.sql
```

### Running Local Checks

```bash
# SQL lint
sqlfluff lint sql/

# Shell lint
shellcheck scripts/*.sh

# Markdown lint
markdownlint docs/ README.md

# Anonymisation sweep (must return zero matches)
bash scripts/check-anonymisation.sh
```

---

## Code Style

### SQL

- One statement per file when it represents a single view, function, or table
- Use lowercase identifiers in DDL (PostgreSQL-idiomatic)
- View prefixes: `vw_dim_*`, `vw_fact_*`, `vw_kpi_*`, `vw_powerbi_*`
- Function prefix: `fn_*`; procedure prefix: `sp_*`
- Schema-qualify only when crossing schemas
- Trailing comma style: leading commas in long SELECT lists for diff-friendliness

### Bash

- `set -euo pipefail` at top of every script
- Quote all expansions: `"$var"`, `"${var}"`
- snake_case for functions, UPPER_CASE for constants
- Must pass `shellcheck --severity=error`

### Markdown

- One H1 per file
- Code fences must declare a language (`sql`, `bash`, `text`, etc.)
- Internal links are relative
- Long tables get a blank line before and after

---

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `perf`, `ci`, `test`.

Example:

```
fix(views/03_kpi): correct WORKING DAY calculation for movable holidays

The vw_kpi_capture_status view counted Easter Monday twice when it
fell into the reporting window. Use fn_working_days_between to dedupe.

Fixes #12
```

---

## Pull Request Process

1. Fork and create a feature branch from `main`
2. Run the local checks listed above (`sqlfluff`, `shellcheck`, `markdownlint`,
   `check-anonymisation.sh`)
3. Update `CHANGELOG.md` under `[Unreleased]`
4. Push and open a PR; describe the motivation and any trade-offs
5. CI must pass; one maintainer review is required

---

## Anonymisation Guardrail

This repository is derived from a real production system through a deterministic
anonymisation pipeline. **Every PR is scanned for forbidden terms** from the
original domain (see `.github/workflows/lint.yml`, job `anonymisation-sweep`).

If your PR fails this check, you have probably:

1. Re-introduced a term from the original source domain by accident, or
2. Pasted text from the original system into a comment.

Fix: rename to the showcase equivalent. The CI job output lists which term
matched. Prefer abstract names: `order`, `provider`, `customer`, `expiry`,
`sentinel`, `source_system`, `intake_date`, `working_days`, etc.

---

## Questions?

- **Documentation**: start with [`docs/`](docs/) (Diátaxis-organised)
- **Discussions**: use GitHub Discussions
- **Security**: see [SECURITY.md](SECURITY.md)

Thank you for contributing!
