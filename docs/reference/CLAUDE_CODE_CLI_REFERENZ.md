# Claude Code CLI-Referenz

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → CLI-Referenz
> **Zweck**: Befehlsreferenz, Output-Formate, SQL-Tools

## Vollständige Befehlsreferenz

### Basis-Befehle
- `claude`: Interaktive REPL-Session
- `claude "query"`: REPL mit initial prompt
- `claude -p "query"`: SDK-Query und exit
- `claude -c`: Letzte Session fortsetzen
- `claude -r "<session-id>" "query"`: Session fortsetzen

### Erweiterte Flags für SQL-Development
- `--add-dir`: SQL-Verzeichnisse hinzufügen
- `--allowedTools`: SQL-Tools spezifizieren
- `--output-format`: Response-Format (text/json)
- `--verbose`: SQL-Performance-Logging
- `--max-turns`: Migration-Steps limitieren

## Output-Formate für SQL-Automation

```bash
# JSON Output für KPI-Validierung
claude -p "validate KPI calculations" --output-format json

# Stream JSON für Migration-Progress
claude -p "migrate table structure" --output-format stream-json

# Text Output für Standard SQL-Development
claude -p "optimize performance" --output-format text
```

## SQL-Verzeichnis Navigation

```bash
# Working Directory Management
claude --add-dir ./vw_Basis --add-dir ./vw_KPI --add-dir ./vw_powerBI
claude --add-dir ./docs

# Bereich-spezifische Sessions
cd vw_KPI && claude -p "optimize KPI view performance"
cd vw_powerBI && claude -p "adapt DirectQuery for Power BI"
```

---
**Siehe auch**:
- [Claude Code Automation](../how-to/CLAUDE_CODE_AUTOMATION.md) - Hooks & Commands
- [PostgreSQL Daily Ops](../how-to/POSTGRESQL_DAILY_OPS.md) - SQL-Workflows
