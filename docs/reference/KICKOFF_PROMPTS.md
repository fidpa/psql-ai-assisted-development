# KICKOFF_PROMPTS.md - Workflow-Zyklen Startanweisungen

*Erstellt am: 2025-07-18*
*Zweck: Kurze, präzise Prompts um die verschiedenen Task Management Zyklen zu starten*

## 🎯 Übersicht

Diese Datei enthält Ready-to-Use Prompts, um die verschiedenen Phasen des Task Management Workflows effizient zu starten. Jeder Prompt ist darauf optimiert, den jeweiligen Zyklus schnell und fokussiert zu initialisieren.

## 📋 Inhaltsverzeichnis

- [🚀 Session-Start Kickoffs](#session-start-kickoffs)
- [📊 Operative Task-Kickoffs](#operative-task-kickoffs)
- [🎯 Strategische Planungs-Kickoffs](#strategische-planungs-kickoffs)
- [🏁 Session-Ende Kickoffs](#session-ende-kickoffs)
- [🔄 Wartungszyklen Kickoffs](#wartungszyklen-kickoffs)
- [🚨 Notfall-Kickoffs](#notfall-kickoffs)

## 🚀 SESSION-START KICKOFFS {#session-start-kickoffs}

### 📝 Standard Session-Start
```markdown
Prüfe die Migration-Phase (🔵🟡🟢) und fokussiere auf die entsprechenden Tasks in TASK.md.
```

### ⚡ Schneller Session-Start
```markdown
```

### 🔍 Session-Start mit Status-Check
```markdown
Führe einen Pre-Session-Check durch:
2. Prüfe TASK.md Migration-Phase
3. Validiere Cross-References
4. Starte mit höchster Priorität
```

### 📊 SQL/Power BI Session-Start
```markdown
SQL/Power BI Session-Start:
2. Prüfe aktuelle Migration-Phase (🔵🟡🟢)
3. Fokus auf KPI-Validierung oder PostgreSQL-Migration
4. Verwende docs/data-platform/ als Referenz
```

## 📊 OPERATIVE TASK-KICKOFFS {#operative-task-kickoffs}

### 🔵 Pre-Migration Focus
```markdown
Fokussiere auf Pre-Migration Tasks:
1. Lese docs/task-management/TASK.md#pre-migration-tasks
2. Priorität: KPI-Validierung und Performance-Baseline
3. Nutze SQL Server Express Limits als Kontext
4. Dokumentiere Fortschritt in TASK.md
```

### 🟡 Migration Execution
```markdown
Migration-Session starten:
1. Lese docs/migration/MIGRATION.md für 3-Wochen-Timeline
2. Prüfe aktuellen Wochen-Status
3. Fokus auf docs/data-platform/PSQL.md für PostgreSQL-Operationen
4. Validiere jeden Schritt gegen Business Rules
```

### 🟢 Post-Migration Optimization
```markdown
Post-Migration Optimierung:
1. PostgreSQL Performance-Tuning
2. Power BI DirectQuery-Optimierung
3. Monitoring und Alerting Setup
4. Nutze docs/data-platform/ als Hauptreferenz
```

### 📈 KPI-Validierung Kickoff
```markdown
KPI-Validierung Session:
1. Lese docs/core/PROJECT.md für Geschäftsregeln
2. Nutze Debug/KPI_Vergleich_Excel_SQL.sql als Baseline
3. Validiere alle kpi_a/kpi_b, S1-S3, D0-D4, V-Werte
4. Dokumentiere Abweichungen >5%
```

### 💻 SQL-Performance Session
```markdown
SQL-Performance Optimierung:
1. Baseline aus TASK.md#performance-baseline laden
2. Fokus auf langsame Views und Queries
3. Express-Limits vs PostgreSQL-Ziele vergleichen
4. Nutze docs/data-platform/PSQL.md für Optimierungen
```

### 📊 Power BI Integration
```markdown
Power BI DirectQuery Session:
1. Lese docs/data-platform/DASHBOARD.md
2. Fokus auf DirectQuery-Kompatibilität
3. Performance-Ziel: <10s Response Time
4. Validiere gegen 1M Rows Limit
```

## 🎯 STRATEGISCHE PLANUNGS-KICKOFFS {#strategische-planungs-kickoffs}

### 📋 PLAN.md Review Session
```markdown
Strategische Planung Review:
1. Lese docs/task-management/PLAN.md
2. Vergleiche strategische Ziele mit TASK.md Fortschritt
3. Update 6-Monats-Roadmap basierend auf aktueller Entwicklung
4. Adjustiere Success Metrics
```

### 🎯 Roadmap Update
```markdown
Roadmap-Aktualisierung:
1. Analysiere abgeschlossene Tasks aus letztem Monat
2. Bewerte strategische Ziele-Erreichung
3. Update PLAN.md Innovation-Pipeline
4. Definiere neue Quarterly Objectives
```

### 📊 Success Metrics Review
```markdown
Success Metrics Evaluation:
1. Sammle aktuelle Performance-Daten
2. Vergleiche mit PLAN.md Target-Werten
3. Identifiziere Trends und Gaps
4. Adjustiere Zielwerte für nächstes Quarter
```

## 🏁 SESSION-ENDE KICKOFFS {#session-ende-kickoffs}

### 🚨 Standard Session-Ende
```markdown
Führe Session-Ende-Workflow durch:
3. Alle Kategorien synchronisieren
4. Cross-References validieren
5. TodoWrite Status finalisieren
```

### ⚡ Schnelle Session-Cleanup
```markdown
Schnelle Session-Cleanup:
2. Details nach docs/[kategorie]/ auslagern
3. TodoWrite als completed/pending markieren
4. Nächste Session vorbereiten
```

### 📋 Vollständige Session-Documentation
```markdown
Vollständige Session-Dokumentation:
2. Session Summary nach Template erstellen
3. Alle docs/[kategorien]/ synchronisieren
4. Quality Assurance durchführen
5. Dokumentations-Konsistenz prüfen
```

### 🔄 Session-Ende mit Wartungscheck
```markdown
Session-Ende mit Maintenance:
2. docs/task-management/PROMPT_LIFECYCLE.md Checks durchführen
3. Automatische Qualitätschecks validieren
4. Wartungszyklen-Status prüfen
```

## 🔄 WARTUNGSZYKLEN KICKOFFS {#wartungszyklen-kickoffs}

### 📅 Tägliche Wartung
```markdown
Tägliche Dokumentations-Wartung:
1. Nutze docs/task-management/PROMPT_LIFECYCLE.md#täglich
3. Cross-References validieren
4. Migration-Phase-Konsistenz 🔵🟡🟢 prüfen
```

### 📅 Wöchentliche Wartung
```markdown
Wöchentliche Dokumentations-Review:
1. Befolge PROMPT_LIFECYCLE.md#wöchentlich
2. Kategorie-Konsistenz validieren
3. Performance-Metriken aktualisieren
4. Sprint-Review in TASK.md dokumentieren
```

### 📅 Monatliche Wartung
```markdown
Monatliche Strategische Review:
1. PROMPT_LIFECYCLE.md#monatlich ausführen
2. PLAN.md Ziele mit TASK.md abgleichen
3. KPI-Definitionen validieren
4. Performance-Baselines aktualisieren
```

### 📅 Quartalsweise Wartung
```markdown
Quartalsweise Architektur-Review:
1. PROMPT_LIFECYCLE.md#quartalsweise befolgen
2. Veraltete Dokumentation identifizieren
3. Kategorien-Struktur optimieren
4. Migration-Dokumentation archivieren (falls 🟢 erreicht)
```

## 🚨 NOTFALL-KICKOFFS {#notfall-kickoffs}

### 🔧 Dokumentations-Reparatur
```markdown
Notfall-Dokumentations-Reparatur:
1. Backup aller .md Dateien erstellen
3. Gebrochene Cross-References reparieren
4. Task Management Workflow wiederherstellen
```

### 🔄 Workflow-Recovery
```markdown
Task Management Workflow-Recovery:
1. docs/task-management/README.md als Referenz nutzen
2. Vollständigen Zyklus validieren
3. Fehlende Verbindungen wiederherstellen
4. Session-Continuity sicherstellen
```

### 🚨 Migration-Phase-Korrektur
```markdown
Migration-Phase-Inkonsistenz reparieren:
1. Aktuelle Migration-Phase ermitteln
2. Alle Dokumente auf 🔵🟡🟢 Konsistenz prüfen
3. TASK.md als Wahrheitsquelle nutzen
4. Cross-References anpassen
```

### 📊 Performance-Crisis Management
```markdown
SQL-Performance-Notfall:
1. Sofortiger Wechsel zu docs/data-platform/PSQL.md
2. Critical Error Responses aktivieren
3. Performance-Baseline vs. Ist-Zustand analysieren
4. Rollback-Plan evaluieren
```

## 🎯 SPEZIELLE KICKOFFS

### 🔄 Migration-Phase-Wechsel
```markdown
Migration-Phase-Transition durchführen:
1. Aktuellen Phase-Status validieren
2. Alle Dokumente von 🔵→🟡 oder 🟡→🟢 aktualisieren
3. Neue Phase-Tasks in TASK.md aktivieren
```

### 📈 KPI-Crisis-Response
```markdown
KPI-Validierung-Crisis:
1. Sofort docs/core/PROJECT.md Geschäftsregeln laden
2. Excel-Referenzen vs. SQL-Calculationen vergleichen
3. Diskrepanzen >5% als CRITICAL behandeln
4. Business Stakeholder informieren
```

### 🚀 Go-Live Preparation
```markdown
PostgreSQL Go-Live Vorbereitung:
1. docs/migration/MIGRATION.md Woche 3 Checkliste
2. Parallelbetrieb-Status prüfen
3. Rollback-Plan testen
4. Performance-Benchmarks finalisieren
```

### 📊 Quarterly Business Review
```markdown
Quarterly Business Review Vorbereitung:
1. PLAN.md Success Metrics sammeln
2. TASK.md Velocity-Tracking analysieren
3. Strategic Objectives vs. Achievements
4. Next Quarter Roadmap definieren
```

## 💡 USAGE TIPS

### Quick Copy-Paste Prompts
```bash
# Speichere häufig genutzte Prompts:
```

### Kontext-Spezifische Prompts
```markdown
# Für SQL-fokussierte Sessions:
"SQL/Power BI Session mit KPI-Validierung und Performance-Focus"

# Für Migration-Sessions:
"Migration-Session: PostgreSQL-Setup und Schema-Conversion"

# Für Cleanup:
```

### Prompt-Chains
```markdown
# Verkettete Prompts für komplexe Workflows:
1. "Session-Start mit Migration-Check"
2. "KPI-Validierung gegen Excel-Referenzen"
3. "Performance-Optimierung für kritische Views"
4. "Session-Ende mit vollständiger Dokumentation"
```

---

**📚 Navigation:**
- **🏠 Übersicht**: [README.md](README.md) - Task Management Architektur
- **🔄 Wartung**: [PROMPT_LIFECYCLE.md](../how-to/PROMPT_LIFECYCLE.md) - Automatische Checks

**🚀 Workflow-Kickoffs:**
- **Session-Start**: Standard, Schnell, SQL/BI-fokussiert
- **Operative Tasks**: Pre-Migration, Migration, Post-Migration  
- **Strategische Planung**: PLAN.md Review, Roadmap Update
- **Session-Ende**: Standard, Schnell, Vollständig
- **Wartung**: Täglich, Wöchentlich, Monatlich, Quartalsweise
- **Notfall**: Dokumentations-Reparatur, Workflow-Recovery

---
*Status: Vollständige Kickoff-Prompts für alle Task Management Zyklen*  
*Zweck: Schneller, fokussierter Start jeder Workflow-Phase*  
*Integration: Nahtlos mit Task Management System verbunden*  
*Letzte Aktualisierung: 2025-07-18*