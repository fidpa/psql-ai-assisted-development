# Entry Points - Thematische Navigation für Claude Code

> **Navigation**: [CLAUDE.md](../../CLAUDE.md) → Entry Points
> **Zweck**: Schnelle Navigation zu relevanten Dokumenten basierend auf Aufgabentyp

## Verfügbare Entry Points

### 🗄️ [SQL & Database Development](SQL_DATABASE_DEVELOPMENT.md)
**Wann nutzen**: SQL-Queries, Views, KPIs, Performance-Probleme
**Häufigkeit**: ⭐⭐⭐⭐⭐ (PRIMARY)

**Quick Start**:
1. [QUICK_REF.md](../imports/QUICK_REF.md) - KPI-Konstanten
2. [POSTGRESQL_DAILY_OPS.md](../how-to/POSTGRESQL_DAILY_OPS.md) - SQL-Befehle
3. [PROJEKT_ARCHITEKTUR.md](../explanation/PROJEKT_ARCHITEKTUR.md) - Business-Logik

---

### 🔄 [PostgreSQL Migration](POSTGRESQL_MIGRATION.md)
**Wann nutzen**: 3-Wochen-Migration, Schema-Conversion
**Häufigkeit**: ⭐⭐⭐⭐ (TIME-SENSITIVE)

**Quick Start**:
1. [TASK_STATUS.md](../reference/TASK_STATUS.md) - 🔵🟡🟢 Phase
2. [POSTGRESQL_MIGRATION_GUIDE.md](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md) - Timeline
3. [POSTGRESQL_MIGRATION_TECHNISCH.md](../tutorial/POSTGRESQL_MIGRATION_TECHNISCH.md) - Technisch

---

### 📊 [Power BI & Analytics](POWER_BI_ANALYTICS.md)
**Wann nutzen**: Dashboards, DirectQuery, DAX Measures
**Häufigkeit**: ⭐⭐⭐ (ANALYTICS)

**Quick Start**:
1. [QUICK_REF.md](../imports/QUICK_REF.md) - KPI-Definitionen
2. [POWER_BI_DAX_KATALOG.md](../reference/POWER_BI_DAX_KATALOG.md) - DAX Measures
3. [POWER_BI_DASHBOARD_ENTWICKLUNG.md](../how-to/POWER_BI_DASHBOARD_ENTWICKLUNG.md) - DirectQuery

---

### 📝 [Session & Documentation Management](SESSION_DOCUMENTATION_MANAGEMENT.md)
**Wann nutzen**: Sessions starten/beenden, Dokumentation pflegen
**Häufigkeit**: ⭐⭐⭐⭐ (DAILY)

**Quick Start**:
1. [SESSION_WORKFLOW.md](../how-to/SESSION_WORKFLOW.md) - Session-Lifecycle
2. [CLAUDE_CODE_KONVENTIONEN.md](../reference/CLAUDE_CODE_KONVENTIONEN.md) - Standards
3. [TASK_STATUS.md](../reference/TASK_STATUS.md) - Phase prüfen

---

### 🔌 [Remote Management & Connectivity](REMOTE_MANAGEMENT_CONNECTIVITY.md)
**Wann nutzen**: Mac ↔ Windows Verbindung, SSH, VPN
**Häufigkeit**: ⭐⭐ (SETUP)

**Quick Start**:
1. [MAC_POSTGRESQL_VERBINDUNG.md](../how-to/MAC_POSTGRESQL_VERBINDUNG.md) - Quick Setup
2. [SSH_SETUP_MAC_WINDOWS.md](../tutorial/SSH_SETUP_MAC_WINDOWS.md) - SSH Step-by-Step
3. [MAC_POSTGRESQL_TOOLS.md](../reference/MAC_POSTGRESQL_TOOLS.md) - Tool-Vergleich

---

## Wie nutzen?

1. **Aufgabentyp identifizieren** → Passenden Entry Point wählen
2. **Decision Tree prüfen** → "🎯 Wann nutzen?"
3. **Quick Start folgen** → Direkter Pfad zu wichtigsten Docs
4. **Hauptpfad durchgehen** → Linearer Workflow
5. **Spezialfälle bei Bedarf** → Verzweigungen für edge cases

---

## Entry Point Struktur

Jeder Entry Point enthält:

- **🎯 Decision Tree**: Wann diesen Entry Point nutzen?
- **⚡ Quick Start**: Direkter Pfad zu 3 wichtigsten Dokumenten
- **📍 Hauptpfad**: Linearer Workflow mit Mermaid-Diagramm
- **🔀 Spezialfälle**: Verzweigungen für Edge Cases
- **📚 Alle relevanten Dokumente**: Nach Diátaxis-Quadranten organisiert
- **🔗 Verwandte Entry Points**: Cross-References

---

## Diátaxis-Quadranten

Die Entry Points verweisen auf Dokumente aus allen 4 Quadranten:

- **📘 Tutorial (Lernen)**: Step-by-Step Anleitungen für Einsteiger
- **🔧 How-To (Aufgaben)**: Schnelle Lösungen für spezifische Probleme
- **📖 Reference (Nachschlagen)**: Fakten, Syntax, Konstanten
- **💡 Explanation (Verstehen)**: Architektur, Designentscheidungen

---

## Häufigste Workflows

### SQL-Entwicklung (PRIMARY)
```
KPI Definition nachschlagen → View-Hierarchie verstehen →
SQL entwickeln → Performance validieren
```
**Entry Point**: [SQL & Database Development](SQL_DATABASE_DEVELOPMENT.md)

### Migration durchführen
```
Phase prüfen (🔵🟡🟢) → Timeline folgen →
Schema konvertieren → Views migrieren → Validieren
```
**Entry Point**: [PostgreSQL Migration](POSTGRESQL_MIGRATION.md)

### Dashboard erstellen
```
KPI definieren → SQL View erstellen →
DAX Measure erstellen → DirectQuery testen → Deployment
```
**Entry Point**: [Power BI & Analytics](POWER_BI_ANALYTICS.md)

### Session starten
```
Session Start → TodoWrite aktivieren →
Standards befolgen → Arbeit erledigen → Session Ende
```
**Entry Point**: [Session & Documentation Management](SESSION_DOCUMENTATION_MANAGEMENT.md)

### Remote-Verbindung einrichten
```
VPN vs SSH entscheiden → Verbindung konfigurieren →
Tool auswählen → Connection testen
```
**Entry Point**: [Remote Management & Connectivity](REMOTE_MANAGEMENT_CONNECTIVITY.md)

---

**Navigation**: [Zurück zu CLAUDE.md](../../CLAUDE.md)
