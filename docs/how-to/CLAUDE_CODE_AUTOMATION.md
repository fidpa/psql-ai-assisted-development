# Claude Code Automation

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Claude Code Automation
> **Zweck**: Custom Commands, Hooks, GitHub Actions, SDK

## Custom Slash Commands

```bash
# SQL Commands
mkdir -p .claude/commands
echo "Test PostgreSQL connectivity:" > .claude/commands/test-psql.md
echo "Validate KPI calculations:" > .claude/commands/validate-kpi.md
echo "Monitor SQL query performance:" > .claude/commands/perf-sql.md

# Usage: /test-psql, /validate-kpi, /perf-sql
```

## Hooks für SQL-Automation

### Configuration (.claude/settings.json)
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit(vw_KPI/*.sql)",
        "hooks": [
          {
            "type": "command",
            "command": "sqlfluff fix {file} && sqlfluff lint {file}"
          }
        ]
      }
    ]
  }
}
```

## GitHub Actions Integration

### SQL-Migration CI/CD Pipeline
```yaml
# .github/workflows/sql-migration-ci.yml
name: SQL Migration CI/CD
on: [push, pull_request]

jobs:
  validate-sql-syntax:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          comment: "@claude validate all SQL views"
```

## SDK & Programmatische Nutzung

### Python SDK für SQL-Migration
```python
from claude_code_sdk import query

async for message in query(
    prompt="Validate KPI calculations",
    options=ClaudeCodeOptions(
        max_turns=8,
        working_directory="./vw_KPI"
    )
):
    if message.type == "response":
        print(f"KPI Validation: {message.text}")
```

---
**Siehe auch**:
- [CLI-Referenz](../reference/CLAUDE_CODE_CLI_REFERENZ.md) - Befehle
- [Dokumentationswartung](../reference/DOKUMENTATIONS_WARTUNG.md) - Wartungsregeln
