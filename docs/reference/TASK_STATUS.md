# Task Status & Checklisten

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Task Status
> **Zweck**: Aktuelle Phase, Checklisten nach Migrationsphasen

## Aktueller Status

### System-Zustand
- **Entwicklungsstand**: 60-70% funktionsfähig ⚠️
- **Hauptproblem**: SQL Server Express Performance-Limits
- **Kritischer Pfad**: KPI-Validierung → Migration → Optimization

### Sprint-Fokus
```
Aktuell: 🔵 Pre-Migration (SQL Server Express)
Nächste: 🟡 Migration (3 Wochen)
Zukunft: 🟢 Post-Migration (PostgreSQL)
```

## Pre-Migration Tasks (🔵)

### Kritisch - Diese Woche
- [ ] kpi_a/kpi_b Validierung gegen Excel-Referenzen
- [ ] S1-S3 Validierung
- [ ] D0-D4 Validierung
- [ ] V-Werte Validierung

### Standard - Nächste Tage
- [ ] Kennziffern.txt Fix (Zeile 6: "52" → "S2")
- [ ] View-Kommentare standardisieren
- [ ] NULL-Handling konsistent

## Migration Tasks (🟡)

### Woche 1: Infrastructure
- [ ] PostgreSQL Setup
- [ ] Sync-Mechanismus
- [ ] Initial Data Load

### Woche 2: View Migration
- [ ] Level 1: Dimensions & Facts
- [ ] Level 2: Business Logic
- [ ] Level 3: Aggregations
- [ ] Level 4: Dashboard Views

### Woche 3: Go-Live
- [ ] Power BI Migration
- [ ] Parallelbetrieb
- [ ] Go-Live Vorbereitung

## Post-Migration Tasks (🟢)

### Immediate
- [ ] Query-Analyse
- [ ] Performance Settings Check
- [ ] Index-Strategie
- [ ] Monitoring Setup

---
**Siehe auch**:
- [Task Tracking](../how-to/TASK_TRACKING.md) - Velocity & Monitoring
- [PostgreSQL Migration Guide](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md) - Timeline
