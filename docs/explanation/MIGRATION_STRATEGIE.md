# Migration-Strategie

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Migration Strategie
> **Zweck**: Warum PostgreSQL, Risiken, Strategische Ausrichtung

## Warum PostgreSQL?

### Aktuelle Situation (SQL Server Express)
- **Performance-Limits**: 1GB RAM, 10GB DB-Größe
- **Kosten**: SQL Server Standard zu teuer
- **Skalierung**: Keine Erweiterungsmöglichkeit

### PostgreSQL Vorteile
- **Performance**: 64GB RAM nutzbar
- **Kosten**: Open Source, keine Lizenzkosten
- **Features**: Materialized Views, Partitioning, JSON-Support
- **Community**: Große Community, aktive Entwicklung

## Risiken & Mitigations

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Datenverlust | Niedrig | Hoch | Tägliche Backups, Validierung |
| Performance-Degradation | Mittel | Hoch | Performance-Tests, Rollback-Plan |
| Power BI Inkompatibilität | Niedrig | Mittel | DirectQuery-Tests, Parallel-Betrieb |
| Migration-Dauer | Mittel | Mittel | 3-Wochen-Timeline, Phasenweise |

## Strategic Rationale

### Architektur-Entscheidungen
- **Docker-basiert**: Einfaches Deployment
- **Daily Sync**: SQL Server bleibt Source of Truth
- **Materialized Views**: Performance für 65M+ Rows
- **Partitioning**: Skalierbarkeit für Appointment-Tabelle

---
**Siehe auch**:
- [PostgreSQL Migration Guide](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md) - Timeline
- [Migration Assessment](../how-to/MIGRATION_ASSESSMENT.md) - Technische Details
