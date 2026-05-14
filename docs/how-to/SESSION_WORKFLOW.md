# Session-Workflow

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Session-Workflow
> **Zweck**: Start, Arbeit, Ende Workflow

## Session-Start Workflow

### 1. Dokumentationsstatus prüfen
```bash
# PROMPT.md Zeilen-Check (MUSS <60 Zeilen sein)
wc -l PROMPT.md

# Task Management Status
cat docs/task-management/TASK.md | grep -E "🔵|🟡|🟢" | head -5
```

### 2. Session-Kontext laden
1. **PROMPT.md** → Aktuelle Session-Prioritäten (max. 60 Zeilen)
2. **docs/task-management/TASK.md** → Operative Aufgaben
3. **docs/migration/MIGRATION.md** → Timeline Status
4. **docs/data-platform/PSQL.md** → PostgreSQL Operations

### 3. TodoWrite aktivieren
```markdown
[{"id": "1", "content": "Priorität 1", "status": "pending"}]
[{"id": "2", "content": "Priorität 2", "status": "pending"}]
```

## Session-Arbeit Guidelines

### SQL/Power BI Spezifische Regeln
- **SQL-Operationen**: 5000ms timeout für psql
- **Migration-Scripts**: 10000ms für komplexe Operationen
- **Power BI Refresh**: 15000ms für BI-Operationen

### Validierungspflicht
- **Vor SQL-Deployment**: KPI-Plausibilität prüfen
- **Nach View-Änderungen**: Performance-Impact messen
- **Power BI Updates**: DirectQuery-Kompatibilität sicherstellen

## Session-Ende Workflow

### 1. TodoWrite Status Review
- Alle Items korrekt als completed/pending markiert?
- Session-Accomplishments dokumentiert?

### 2. Dokumentation synchronisieren
- TASK.md bei Migration-Fortschritt aktualisieren
- PROJECT.md bei Geschäftslogik-Änderungen
- PSQL.md bei PostgreSQL-Operationen

### 3. PROMPT.md Cleanup (OBLIGATORISCH!)
- Datei > 60 Zeilen? → Sofort bereinigen!
- SQL-Details → docs/data-platform/
- Migration-Details → docs/migration/
- Geschäftsregeln → docs/core/PROJECT.md

---
**Siehe auch**:
- [Dokumentations-Wartung](../reference/DOKUMENTATIONS_WARTUNG.md) - Regeln
- [Task Tracking](TASK_TRACKING.md) - Velocity & Monitoring
