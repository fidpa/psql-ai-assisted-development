# Security Policy

## Project Status

This repository is a **reference implementation / showcase** that demonstrates
patterns for AI-assisted PostgreSQL development. It is published in archival
mode — no active feature development, but security-relevant fixes are accepted.

| Version | Supported          | Status |
|---------|--------------------|--------|
| 1.0.x   | Yes                | Active |
| < 1.0   | No                 | Pre-release |

---

## Reporting a Vulnerability

Although this is a showcase repository (SQL views, scripts, configuration),
please follow responsible disclosure if you find a security issue that could
affect users who adopt these patterns.

**Do NOT** open a public GitHub issue for security vulnerabilities.

Report via:

1. **GitHub Security Advisories** (preferred):
   <https://github.com/fidpa/psql-ai-assisted-development/security/advisories>
2. Open a private discussion thread.

### Report Template

```markdown
## Vulnerability Description
[Clear description of the issue]

## Impact
[How could a user of these patterns be harmed? Data exposure, privilege
escalation, SQL injection, etc.]

## Steps to Reproduce
1. ...

## Suggested Fix
[Optional]

## Environment
- PostgreSQL version:
- OS:
- Commit / tag:
```

### Response Timeline

| Stage              | Timeline    |
|--------------------|-------------|
| Acknowledgment     | 7 days      |
| Initial Assessment | 14 days     |
| Fix / Advisory     | 30-90 days  |

(Timelines reflect showcase-mode maintenance — best-effort, not SLA.)

---

## Security Considerations for Adopters

When adapting patterns from this repository to your own system:

### 1. Credentials

- Never commit database passwords. The example `psql` invocations rely on
  `${PGPASSWORD}` or `~/.pgpass`. The original system this project was
  derived from once had a hardcoded password in documentation — that mistake
  is intentionally retained in `docs/explanation/` as a teaching moment.

### 2. Privileges

- The provided views and procedures assume an application user with
  `SELECT`/`EXECUTE` on the schema. Avoid running them as `postgres` superuser
  in production.

### 3. SQL Injection

- All examples use parameterized queries or pure DDL. If you wrap views in
  application code, never concatenate user input into SQL strings.

### 4. Materialized Views

- The incremental refresh procedure uses advisory locks. Verify your locking
  strategy works for your concurrency profile before adopting it.

### 5. PostgreSQL Tuning Config

- `config/postgres-tuning-64gb.conf` is tuned for a dedicated 64 GB RAM host
  on NVMe. Blindly applying it to a smaller or shared host will degrade
  performance and may exhaust memory. Read `docs/reference/POSTGRES_TUNING.md`
  before deploying.

---

## Anonymisation Notice

This repository is derived from a real-world production system through a
deterministic anonymisation pipeline. A CI check (`.github/workflows/lint.yml`,
job `anonymisation-sweep`) blocks any commit that reintroduces a forbidden
term from the original domain. If you find a leaked identifier, please report
it as a vulnerability.

---

## Acknowledgments

Security researchers who help improve this showcase will be credited here.

*No security reports yet.*
