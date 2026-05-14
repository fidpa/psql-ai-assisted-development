# OrderProcessing KPI Dashboard - Projektdokumentation

## 📑 TABLE OF CONTENTS
- [1. PROJEKTÜBERSICHT](#1-projektübersicht)
- [2. DATENMODELL UND ARCHITEKTUR](#2-datenmodell-und-architektur)
- [3. KPI-DEFINITIONEN](#3-kpi-definitionen)
- [4. GESCHÄFTSLOGIK](#4-geschäftslogik)
- [5. PERFORMANCE-OPTIMIERUNGEN](#5-performance-optimierungen)
- [6. TECHNISCHE DETAILS](#6-technische-details)
- [7. DATENQUALITÄT UND VALIDIERUNG](#7-datenqualität-und-validierung)
- [8. BEKANNTE PROBLEME UND LÖSUNGSANSÄTZE](#8-bekannte-probleme-und-lösungsansätze)
- [9. DEPLOYMENT UND WARTUNG](#9-deployment-und-wartung)

## 1. PROJEKTÜBERSICHT

### 1.1 Zielsetzung
Entwicklung eines robusten, wartbaren KPI-Dashboard-Systems zur tagesaktuellen Überwachung einer mehrstufigen Document-Processing-Pipeline mit Order- und Provider-Bezug.

### 1.2 Geschäftskontext
Das Backoffice verarbeitet täglich tausende von Orders verschiedener Partner-Sites. Das System überwacht kritische Kennzahlen entlang einer fünfstufigen Pipeline:
- **Intake**: Tracking des Eingangs (`stage_1`)
- **Classification**: Automatisch vs. manual zu bearbeitende Orders (`stage_2`)
- **Digitisation**: Scan-Backlog (`stage_3`)
- **Registration**: Captures-Backlog (`stage_4`)
- **Retention tracking**: Konfigurierbares Aufbewahrungsfenster, Default 180 Tage (`stage_5`)
- **Controlling**: Finanzielle Überwachung des Invoice-Pipelines

Die Pipeline-Stufen sind generisch — das Muster ist gleichwertig anwendbar auf Insurance-Claim-Handling, Legal-Document-Review, Logistics-Returns oder jeden anderen mehrstufigen Backoffice-Workflow mit Eingangs-Frist und Status-Tracking.

### 1.3 Technische Anforderungen
- **SQL Server** als zentrale Datenquelle
- **Power BI** mit DirectQuery für Echtzeit-Dashboards
- **Keine Datenreplikation** (Performance-Optimierung auf SQL-Ebene)
- **Wartbare, dokumentierte Lösung**

## 2. DATENMODELL UND ARCHITEKTUR

### 2.1 Schichtenmodell
```
┌─────────────────────────────────┐
│     Power BI Dashboard          │ ← Präsentationsschicht
├─────────────────────────────────┤
│     DAX Measures               │ ← Calculationslogik
├─────────────────────────────────┤
│     vw_PowerBI_* Views         │ ← Optimierte Interface-Views
├─────────────────────────────────┤
│     vw_KPI_* Views             │ ← Geschäftslogik-Views
├─────────────────────────────────┤
│     vw_Fact_* / vw_Dim_*      │ ← Basis-Views (Star Schema)
├─────────────────────────────────┤
│     Quelltabellen              │ ← Rohdaten
└─────────────────────────────────┘
```

### 2.2 Zentrale Quelltabellen
- **OrderIntake**: Posteingang pro Provider und Tag
- **Order**: SingleOrders mit Service- und Billing-Daten
- **Provider**: Partner-Sites mit ServiceTypes und Automationsregeln
- **InvoiceInsurer**: Invoice-Status pro Partner
- **Appointment**: High-volume Event-Tabelle (65+ Mio. Datensätze — Performance-Lehrstück)
- **ProviderGroupAssignment**: Partner-Tier-Klassifizierung

### 2.3 Basis-Views (vw_Basis/)
#### Dimensionstabellen
- **vw_Dim_Provider**: Zentrale Providerdimension mit Geschäftslogik
  - Sentinel-Erkennung (ProviderGroupIDs 1, 2)
  - SourceSystem-Integration
  - Automations-Flags
- **vw_Dim_WorkingDays**: WorkingDayskalender mit Holidays
- **vw_Dim_Customer**: CustomerMasterData
- **vw_Dim_InvoiceInsurer**: InsurerInvoicesdimension

#### Faktentabellen  
- **vw_Fact_OrderIntake**: Bereinigte OrderIntake data
- **vw_Fact_Order**: Zentrale OrderFactstabelle
- **vw_Fact_Expiry**: Expirationen
- **dbo.Fact_Expiry_Mat**: Materialisierte Tabelle für Performance

### 2.4 KPI-Views (vw_KPI/)
#### E-Werte (Empfang)
- **vw_KPI_OrderSorting**: Basis für Sorting-Logik
- **vw_KPI_OrderIntake_KPIs**: kpi_a/kpi_b Calculationen

#### S-Werte (Scanning)  
- **vw_KPI_Scanning_Aggregated**: S1-S3 Calculationen

#### D-Werte (Datencapture)
- **vw_KPI_Capture_Aggregated**: D0-D3 Calculationen
- **vw_KPI_CaptureStatus_Complete**: Basis-View für CaptureStatus

#### V-Werte (Expiry)
- **vw_KPI_Expiry**: Expiry monitoring

#### C-Werte (Controlling)
- **vw_KPI_Controlling**: Finanzielle Kennzahlen

#### Dashboard-Integration
- **vw_KPI_Dashboard_Gesamt**: Zentrale Aggregation aller KPIs

### 2.5 Power BI Views (vw_powerBI/)
- **vw_PowerBI_Dashboard_Live**: Optimiert für DirectQuery
- **vw_PowerBI_ProviderAnalyse**: Provider-spezifische Analysen  
- **vw_PowerBI_Historie**: Historische Trends
- **vw_PowerBI_OrderIntakeDetail**: Detailanalysen

## 3. KPI-DEFINITIONEN

### 3.1 E-Werte (Empfang)
- **kpi_a**: Posteingang am vergangenen Arbeitstag
- **kpi_b**: Posteingang in den vergangenen 3 WorkingDays

### 3.2 S-Werte (Scanning)
- **S1**: Pending scan in den kommenden 3 WorkingDays
- **S2**: Pending scan in den kommenden 6 WorkingDays  
- **S3**: Pending scan insgesamt

### 3.3 D-Werte (Datencapture)
- **D0**: Pending capture heute
- **D1**: Pending capture in den kommenden 3 WorkingDays
- **D2**: Pending capture in den kommenden 6 WorkingDays
- **D3**: Pending capture insgesamt
- **D4**: Expiring Orders ohne InsurerInvoice

### 3.4 V-Werte (Expiry)
- Orders, die in den nächsten 20 WorkingDays das Retention-Fenster verlassen
- Konfigurierbares Retention-Fenster (Default 180 Tage) ab dem letzten Referenz-Event

### 3.5 C-Werte (Controlling)  
- **C1**: Nettosumme unbestätigter InsurerInvoices
- **C2**: Anzahl unbestätigter InsurerInvoices

## 4. GESCHÄFTSLOGIK

### 4.1 Classification-Logik (Basis für kpi_a/kpi_b)
Orders müssen **NICHT** manual klassifiziert werden, wenn:
- ServiceType in einer der vier automatisierten Kategorien liegt (`service_type_id IN (10, 20, 30, 40)`)
- Der Eingang bereits über einen elektronischen Channel kam (`import_type IN (1, 2)`)
- Der zugehörige Provider zu einem Partner-Tier mit Auto-Routing gehört
- Eine `SourceSystem`-Integration die Daten strukturiert liefert

### 4.2 Partner-Tier-Erkennung
```sql
EXISTS (
    SELECT 1 FROM ProviderGroupAssignment bgz
    WHERE bgz.ProviderID = b.ProviderID
    AND bgz.ProviderGroupID IN (1, 2) -- Partner tiers A and B
)
```

### 4.3 WorkingDays-Calculation
- Montag-Freitag (Wochenenden ausgeschlossen)
- Region-spezifische Holidays berücksichtigt (DACH-Kalender als Beispiel)
- Ostern als Anker für bewegliche Holidays über `fn_easter_sunday`

### 4.4 Retention-Logik
- 180 Tage nach dem letzten Referenz-Event (konfigurierbar)
- Berechnet nur für den retail-account-Pfad (`account_class = 'retail'`)
- Ausschluss gelöschter oder korrigierter Orders

## 5. PERFORMANCE-OPTIMIERUNGEN

### 5.1 Materialisierte Tabellen
- **dbo.Fact_Expiry_Mat**: Löst Performance-Problem bei 65+ Mio. appointments
- **sp_Aktualisiere_Expiry_Mat_Inkrementell**: Effiziente Updates

### 5.2 View-Optimierungen
- Aggregierte Views (statt Basis-Views) für bessere Performance
- DirectQuery-optimierte Power BI Views
- Indices auf kritischen Joins

### 5.3 Entwicklungsumgebung
- DEV-Views mit vw_DEV_ Prefix für Testing
- Power Query Parameter für Umgebungsumschaltung

## 6. TECHNISCHE DETAILS

### 6.1 Datenbankverbindung
- **Server**: legacy-mssql-host\SQLEXPRESS  
- **Datenbank**: order_processing
- **Connection**: Trusted_Connection=True

### 6.2 Namenskonventionen
- **vw_Dim_**: Dimensionstabellen
- **vw_Fact_**: Faktentabellen  
- **vw_KPI_**: Geschäftslogik/Calculationen
- **vw_PowerBI_**: Power BI-optimierte Views
- **sp_**: Stored Procedures
- **fn_**: Functions

### 6.3 Power BI Integration
- DirectQuery für Echtzeit-Daten
- DAX Measures für Trend-Calculationen
- Bedingte Formatierung über Status-Felder
- Parameter-gesteuerte Entwicklungsumgebung

## 7. DATENQUALITÄT UND VALIDIERUNG

### 7.1 Implementierte Checks
- Date-Cleanup in vw_Fact_Order
- NULL-Behandlung mit ISNULL()
- ImportFehler-Ausschluss
- Gelöschte/Korrigierte Orders-Behandlung

### 7.2 Debug-Tools
- KPI_Vergleich_Excel_SQL.sql für Validierung
- Performance-Monitoring Views
- Datenqualitäts-Reports

## 8. BEKANNTE PROBLEME UND LÖSUNGSANSÄTZE

### 8.1 Performance-Herausforderungen
- **Problem**: 65+ Mio. appointments führen zu langsamen Expiries-Queries
- **Lösung**: Materialisierte Tabelle mit inkrementellen Updates

### 8.2 Code-Wartung
- Doppelte Logik in verschiedenen Views
- Inkonsistente Namenskonventionen in Legacy-Code
- Auskommentierter Test-Code in Produktions-Views

### 8.3 Zukünftige Optimierungen
- Weitere Materialisierte Views für komplexe Aggregationen
- Automatisiertes Performance-Monitoring
- Standardisierte Fehlerbehandlung

## 9. DEPLOYMENT UND WARTUNG

### 9.1 Aktueller Status
- System ist ~60-70% funktionsfähig implementiert
- KPI-Strukturen (kpi_a/kpi_b, S1-S3, D0-D4, V, C1/C2) vorhanden, aber nicht vollständig validiert
- Power BI Dashboard technisch verbunden, aber noch nicht produktionsreif
- **Kritische Bereiche**: Performance-Probleme, unvalidierte Calculationslogik, fehlende Fehlerbehandlung

### 9.2 Wartungsaufgaben
- Tägliche Index-Wartung
- Wöchentliche Statistik-Updates  
- Monatliche Performance-Reviews
- Expiries-Materialized-View Updates

Diese Dokumentation bildet die Grundlage für alle weiteren Entwicklungs- und Wartungsarbeiten am KPI-Dashboard-System.

---

## 🔗 TECHNISCHE IMPLEMENTATION REFERENZEN

### PostgreSQL Migration & Operations
Für die vollständige technische Umsetzung der in diesem Dokument beschriebenen Geschäftslogik:

**Tägliche PostgreSQL-Operationen:**
- **[PSQL.md](../reference/POSTGRESQL_REFERENZ.md)**: Sofort ausführbare Befehle für KI-Assistenten (174 Zeilen)
- **Verwendung**: Tägliche Wartung, KPI-View Erstellung, Performance-Checks

**Detaillierte PostgreSQL-Implementierung:**
- **[PSQL_TEMPLATE.md](../reference/POSTGRESQL_REFERENZ.md)**: Vollständige Funktions-Definitionen (2300+ Zeilen)
- **Verwendung**: Schema-Migration, Error Handling, Enterprise-Grade Operations

**Migration & Projekt-Management:**
- **[MIGRATION.md](../tutorial/POSTGRESQL_MIGRATION_GUIDE.md)**: 3-Wochen PostgreSQL-Migrations-Timeline
- **[TASK.md](../reference/TASK_STATUS.md)**: Operative Aufgaben nach Migrationsphasen (🔵🟡🟢)

### View-Hierarchie Implementation
Die in Kapitel 2.1 beschriebene Schichtenarchitektur wird implementiert durch:

```sql
-- Beispiel aus PSQL.md für KPI-View-Erstellung:
CREATE OR REPLACE VIEW vw_KPI_[NAME] AS
SELECT 
    [DATUM] as datum,
    [KENNZAHL] as kpi_wert,
    [KATEGORIE] as kategorie
FROM [BASIS_VIEW]
WHERE [FILTER_BEDINGUNG];
```

**Automatisierte View-Erstellung:** Siehe [PostgreSQL-Referenz](../reference/POSTGRESQL_REFERENZ.md)

### Performance-Optimierung Implementation
Die in Kapitel 5 beschriebenen Performance-Strategien werden umgesetzt durch:

- **Materialized Views**: [PostgreSQL-Referenz - Automated Backup & Maintenance](../reference/POSTGRESQL_REFERENZ.md)
- **Partitionierung**: [PostgreSQL-Referenz - Advanced Operations](../reference/POSTGRESQL_REFERENZ.md)
- **Index-Strategien**: [PostgreSQL-Referenz - Performance Optimization](../reference/POSTGRESQL_REFERENZ.md)

---

**📚 NAVIGATION ZU ANDEREN DOKUMENTEN**:
- **🏠 Master-Index**: [CLAUDE.md](../../CLAUDE.md) - KI-Assistent Direktiven
- **🔧 PostgreSQL**: [PSQL.md](../reference/POSTGRESQL_REFERENZ.md) - Tägliche Operationen | [PSQL_TEMPLATE.md](../reference/POSTGRESQL_REFERENZ.md) - Vollständige Referenz
- **📋 ROADMAP**: [PLAN.md](STRATEGISCHE_VISION.md) - Strategische Vision
- **✅ AUFGABEN**: [TASK.md](../reference/TASK_STATUS.md) - Operative Tasks
- **🔍 TROUBLESHOOTING**: [KNOWLEDGE.md](../reference/SQL_SERVER_LEGACY.md) - Wissensdatenbank
- **📊 POWER BI**: [DASHBOARD.md](../how-to/POWER_BI_DASHBOARD_ENTWICKLUNG.md) - DAX-Measures und Design

---
*Letzte Aktualisierung: 2025-07-10*  
*Status: Vollständig integriert mit PostgreSQL-Dokumentation*