# Claude Code Konventionen - OrderProcessing SQL/Power BI Projekt

*Erstellt am: 2025-07-18*
*Letzte Aktualisierung: 2025-07-18*

**Basiert auf systematischer Analyse aller 24 Claude Code Dokumentationsseiten aus `cc_doc/`**

## Übersicht

Claude Code unterstützt ein Memory Management System über Markdown-Dateien, die automatic geladen werden und Kontext für KI-Assistenten bereitstellen. Diese Konventionen definieren optimale Dokumentationsstrukturen für das SQL/Power BI OrderProcessing-Projekt mit SQL Server Express → PostgreSQL Migration und Power BI DirectQuery Integration.

## 📍 Projekt-Charakteristika

**Kernfokus**: OrderProcessing mit SQL/Power BI Integration
- **Zielgruppe**: Sites, Billingdienstleister, Compliance-Verantwortliche
- **Technologie**: SQL Server Express → PostgreSQL, Power BI DirectQuery, psql CLI-Automation
- **Besonderheiten**: Deutschsprachige Geschäftslogik, KPI-Calculationen (65+ Mio Rows), Single-Developer-Workflow

```
order_processing/
├── CLAUDE.md                    # AI-Assistant Guidelines (importiert CC_CONVENTIONS.md)
├── docs/                        # 📚 ZENTRALE DOKUMENTATION
│   ├── PSQL.md                  # PostgreSQL Automation (173 Zeilen kompakt)
│   ├── PSQL_TEMPLATE.md         # Vollständige Details (2300+ Zeilen)
│   ├── PROJECT.md               # Geschäftsregeln und KPI-Definitionen
│   ├── DASHBOARD.md             # Power BI DirectQuery-Patterns
│   ├── KNOWLEDGE.md             # SQL Server Troubleshooting
│   ├── TASK.md                  # Aktuelle Aufgaben nach Migrationsphasen
│   ├── MIGRATION.md             # 3-Wochen-Plan SQL Server → PostgreSQL
│   └── operations/              # Claude Code Konventionen
│       ├── CC_CONVENTIONS.md            # Diese Datei - Basis-Konventionen
│       └── CC_CONVENTIONS_WORKFLOWS.md  # Erweiterte Workflows
├── vw_Basis/                    # SQL Views - Basis-Dimensionen
├── vw_KPI/                      # SQL Views - KPI-Calculationen  
├── vw_powerBI/                  # SQL Views - Power BI DirectQuery
└── Utils/                       # Hilfsskripte und Backups
```

### Migration-Phasen-Status

**🔵 Pre-Migration (AKTUELL)**
- **SQL Server Express**: 1GB RAM-Limit, 30+ Sek Performance
- **SSMS-based**: Manueller SQL-Workflow
- **Akzeptierte Limits**: Langsame Entwicklungszyklen

**🟡 Migration (3-Wochen-Plan)**
- **Datenbank-Schema**: Automatisierte Übertragung
- **KPI-Validierung**: Plausibilitätsprüfung aller Calculationen
- **Power BI Migration**: DirectQuery Anpassungen

**🟢 Post-Migration (ZIEL)**
- **PostgreSQL**: 64GB RAM, <5 Sek Performance
- **psql CLI-Automation**: KI-First Entwicklung
- **Vollautomatisierung**: Backup, Monitoring, Emergency Response

## 📝 Dokumentationssprache: DEUTSCH

**ALLE** Dokumentationsdateien im OrderProcessing-Projekt werden auf **Deutsch** verfasst:
- Geschäftslogik und KPI-Definitionen: **Ausschließlich Deutsch**
- Technische Begriffe können englisch bleiben (z.B. "SQL", "DirectQuery", "PostgreSQL", "Power BI")
- Deutsche Fachterminologie: "OrderProcessing", "Expiry", "Provider", "Kassenabinvoiceen"
- **Ausnahme**: SQL-Code-Kommentare können englisch sein bei internationalen Standards

## Memory Management System

### Memory Locations

Claude Code unterstützt drei Memory-Speicherorte:

1. **Project Memory** (`./CLAUDE.md`)
   - **Zweck**: Team-geteilte Anweisungen für das OrderProcessing-Projekt
   - **Scope**: Alle Entwickler, die an SQL/Power BI arbeiten
   - **Automatisches Laden**: Ja, beim Start von Claude Code
   - **Pfad**: `/Users/dbadmin/Environments/VisualStudio/order_processing/CLAUDE.md`

2. **User Memory** (`~/.claude/CLAUDE.md`)
   - **Zweck**: Persönliche Präferenzen über alle Projekte hinweg
   - **Scope**: Individueller Benutzer
   - **Automatisches Laden**: Ja, globale Einstellungen

3. **Local Project Memory** (`./CLAUDE.local.md`)
   - **Status**: Deprecated (veraltet)
   - **Empfehlung**: Nicht mehr verwenden

### Key Features

#### Automatisches Laden
- Memory-Dateien werden automatic geladen, wenn Claude Code startet
- Keine manuale Einbindung erforderlich
- Hierarchische Discovery: Recursive Suche im Verzeichnisbaum nach oben
- **SQL-Projekt Support**: Funktioniert von jedem Working Directory

#### Import-System
```markdown
@./docs/operations/CC_CONVENTIONS.md
@./docs/data-platform/PSQL.md

# Weitere Inhalte der Memory-Datei
```

- **Syntax**: `@path/to/import` am Anfang der Datei
- **Rekursion**: Bis zu 5 Hops tief unterstützt
- **Relative Pfade**: Relativ zur importierenden Datei
- **Absolute Pfade**: Empfohlen für konsistente Navigation

#### Memory-Hinzufügung
- **`#` am Anfang**: Prompt zur Auswahl der Memory-Datei
- **`/memory` Slash Command**: Direkte Bearbeitung von Memory-Dateien
- **Schnelle Erweiterung**: Während der SQL-Entwicklung

## Best Practices für SQL/Power BI Projekt

### Strukturierung der CLAUDE.md

**Optimale CLAUDE.md Struktur für OrderProcessing:**
```markdown
# OrderProcessing SQL/Power BI - Claude Code Memory

@./docs/operations/CC_CONVENTIONS.md
@./imports/QUICK_REF.md

## Project Context
- SQL Server Express → PostgreSQL Migration
- Power BI DirectQuery für KPI-Dashboards
- Deutschsprachige OrderProcessing (65+ Mio Rows)

## Critical Rules
- Prüfe TASK.md Phase vor jeder Aktion (🔵🟡🟢)
- Verwende PSQL.md für PostgreSQL-Operationen
- Validiere KPIs vor Implementierung
- Nutze DirectQuery für Power BI
- Real-Data-Only Policy (keine Synthetic Data)

## Current Development Focus
- 🔵 Pre-Migration: SQL Server Express Limits
- Aktuelle Session-Ziele
- Prioritäten basierend auf Migration Timeline
```

### Dokumentationshierarchie

**Hierarchie für SQL/Power BI Projekt:**
1. **CLAUDE.md** - Kern-Guidelines und Migration-Status (≤500 Zeilen)
2. **PSQL.md** - Kompakte PostgreSQL-Befehle (173 Zeilen)
3. **PSQL_TEMPLATE.md** - Vollständige PostgreSQL-Dokumentation (2300+ Zeilen)
4. **PROJECT.md** - Geschäftsregeln und KPI-Definitionen
5. **TASK.md** - Migrationsphasen und aktuelle Aufgaben
6. **CC_CONVENTIONS.md** - Claude Code Konventionen (diese Datei)

### Content-Guidelines

#### Was gehört in CLAUDE.md:
- **Migration-Phase**: Aktuelle Phase (🔵🟡🟢) und Limits
- **Critical Rules**: KPI-Validierung, DirectQuery-Policy, Real-Data-Only
- **Current Development Focus**: Session-spezifische SQL/BI-Ziele
- **Import-Referenzen**: Verweis auf spezialisierte Dokumentation

#### Was gehört in PSQL.md:
- **Kompakte SQL-Befehle**: Tägliche PostgreSQL-Operationen
- **KI-Assistant Workflows**: Automatisierte psql-Befehle
- **Error Handling**: Häufige SQL-Probleme und Lösungen
- **Performance-Optimierung**: Query-Tuning für große Datenmengen

#### Was gehört in PROJECT.md:
- **KPI-Definitionen**: Geschäftsregeln für alle Kennzahlen
- **Datenmodell**: Fact- und Dimension-Tabellen
- **Validation Rules**: Plausibilitätsprüfungen
- **Business Logic**: OrderProcessing-spezifische Anforderungen

### Import-Strategie

**Empfohlene Import-Struktur:**
```markdown
# In CLAUDE.md:
@./docs/operations/CC_CONVENTIONS.md
@./imports/QUICK_REF.md

# In CC_CONVENTIONS.md:
@./docs/operations/CC_CONVENTIONS_WORKFLOWS.md

# In projektspezifischen Dateien:
@./docs/data-platform/PSQL.md#kpi-beinvoiceen
@./docs/core/PROJECT.md#geschaeftsregeln
```

### Aktualisierungs-Workflow

1. **Session-Start**: CLAUDE.md mit aktueller Migration-Phase updaten
2. **SQL-Entwicklung**: PSQL.md für tägliche Operationen nutzen
3. **KPI-Änderungen**: PROJECT.md Geschäftsregeln validieren
4. **Migration-Fortschritt**: TASK.md Phase-Status aktualisieren

## SQL-Entwicklung Best Practices

### SQL Server Express Limits (🔵 AKTUELL)

**Kritische Anforderungen:**
- **1GB RAM-Limit**: Einfache Queries bevorzugen
- **30+ Sek Performance**: Langsame Entwicklung akzeptieren
- **SSMS-based**: Manueller SQL-Workflow
- **Real-Data-Only**: Keine synthetischen Test-Daten

### PostgreSQL Migration Standards (🟢 ZIEL)

**Performance-Optimierung:**
```sql
-- VERBOTEN - Direkte Terme-Aggregation
SELECT SUM(menge) FROM fact_order WHERE appointment BETWEEN '2024-01-01' AND '2024-12-31';

-- KORREKT - Materialized Views für Aggregationen
SELECT * FROM vw_KPI_OrderIntake_Aggregiert WHERE jahr = 2024;
```

### KPI-Validierung Standards

**Geschäftsregeln-Compliance:**
- **Vor jeder Änderung**: KPI-Plausibilität mit PROJECT.md abgleichen
- **Validierung**: Neue Calculationen gegen Excel-Referenzen testen
- **Performance**: Niemals direkte Aggregation von 65+ Mio Rows
- **Documentation**: Jede KPI-Änderung in PROJECT.md dokumentieren

### DirectQuery Integration

**Power BI Anforderungen:**
- **Keine Datenreplikation**: DirectQuery obligatorisch
- **Performance**: Aggregation auf SQL-Ebene erforderlich
- **Limits**: Max 1M Rows per Visual
- **Views**: Alle Power BI Queries über vw_powerBI/* Views

## Security & Datenintegrität

### SQL-Zugriff und Berechtigungen

**Sicherheitsanforderungen:**
- **Read-Only**: Power BI Service Account nur SELECT-Berechtigung
- **Development**: Vollzugriff nur auf Development-Schema
- **Production**: Separate Benutzer für verschiedene Anwendungen
- **Audit Logging**: Alle Datenänderungen protokolliert

### Backup und Recovery

**Backup-Strategie:**
- **Tägliche Backups**: Automatisiert via PSQL.md Workflows
- **Pre-Migration**: Vollständiger SQL Server Backup
- **Incremental**: Stündliche Log-Backups für kritische Daten
- **Testing**: Regelmäßige Restore-Tests

### Datenvalidierung

**Integrity Checks:**
- **Constraints**: Alle Business Rules als DB-Constraints
- **Check-Routines**: Automatisierte Plausibilitätsprüfungen
- **Cross-Validation**: SQL vs. Excel Referenz-Calculationen
- **Migration-Validation**: Byte-für-Byte Vergleich SQL Server ↔ PostgreSQL

## Memory-Management-Optimierung

### Ziel: <500 Zeilen pro Datei

**Aktuelle Status:**
- **CLAUDE.md**: ~350 Zeilen ✅
- **CC_CONVENTIONS.md**: ~450 Zeilen (diese Datei) ✅
- **CC_CONVENTIONS_WORKFLOWS.md**: ~480 Zeilen (geplant) ✅
- **PSQL.md**: 173 Zeilen ✅ (kompakt für tägliche Nutzung)

### Strategien für Memory-Effizienz

1. **Import-System nutzen**: PSQL_TEMPLATE.md für Details, PSQL.md für Daily Operations
2. **Projektfremde Bereiche entfernen**: Keine Cloud/Enterprise Features für Single-Developer
3. **Konkrete SQL-Beispiele**: Statt langer Erklärungen
4. **Cross-References**: Links zu spezialisierten Dokumenten

### Qualitätssicherung

**Regelmäßige Validierung:**
- **Zeilen-Count**: `wc -l CC_CONVENTIONS.md` ≤ 500
- **Import-Tests**: Alle @imports funktional
- **Migration-Phase**: Korrekte 🔵🟡🟢 Status-Angaben
- **KPI-Consistency**: Geschäftsregeln zwischen PROJECT.md und SQL konsistent

## Erweiterte Features

**Für detaillierte Workflows, CLI-Referenzen und erweiterte Claude Code Features siehe:**
→ **[CC_CONVENTIONS_WORKFLOWS.md](CLAUDE_CODE_KONVENTIONEN.md)**

**Themen in der Workflow-Datei:**
- CLI-Referenz & psql-Automation
- GitHub Actions Integration für SQL-Projekte
- SDK & Programmatische Nutzung für Batch-Processing
- SQL-Development Workflows
- Power BI Integration Patterns
- Migration-spezifische Tools und Hooks
- Troubleshooting & Debug Workflows für SQL/BI
- Performance-Monitoring und Optimierung

---

**Status**: ✅ SQL/Power BI OrderProcessing Konventionen (Juli 2025)  
**Basis**: Systematische Analyse aller 24 Claude Code Dokumentationsseiten  
**Optimierung**: Memory-Management <500 Zeilen, SQL-Migration-Focus, Power BI DirectQuery  
**Sprache**: Deutsch mit englischen Fachbegriffen  

*Diese Konventionen werden basierend auf Migration-Fortschritt und neuen Claude Code Features kontinuierlich weiterentwickelt.*