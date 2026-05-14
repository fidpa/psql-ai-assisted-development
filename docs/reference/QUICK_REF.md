# Quick Reference - Importierte Definitionen

## 🎯 KPI-Kategorien & Definitionen

### E-Werte (Empfang)
- **kpi_a**: Eingegangene Orders heute
- **kpi_b**: Empfangsbacklog (≥2 Tage alt)

### S-Werte (Scanning)
- **S1**: Zu scanningde Orders heute
- **S2**: Gescanse Orders heute
- **S3**: Scan-Backlog (≥2 Tage alt)

### D-Werte (Datencapture)
- **D0**: Ungescanse Orders (Scan-Backlog)
- **D1**: Zu capturede Orders heute
- **D2**: Erfasste Orders heute
- **D3**: Captures-Backlog (≥2 Tage alt)
- **D4**: CaptureStatus (%)

### V-Werte (Expiry)
- **V1**: Expirysrelevante Orders
- **V2**: Kritische Expiry (≤30 Tage)

### C-Werte (Controlling)
- **C1**: Billingvolumen heute
- **C2**: Durchschnittlicher Invoicebetrag

## 🔧 Technische Konstanten

### PostgreSQL-Verbindung
```bash
# Standard psql-Befehl
powershell.exe "\$env:PGPASSWORD='${PGPASSWORD}'; & 'C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe' -h localhost -p 5432 -U postgres -d postgres -c \"SQL_HIER\""
```

### SQL Server Express Limits
- **RAM**: 1GB (statt 64GB verfügbar)
- **CPU**: 1 Core (statt 16 verfügbar)
- **DB-Größe**: 10GB Maximum
- **Performance**: 30+ Sekunden für Expiries-Queries

### Power BI Patterns
- **DirectQuery**: Keine Datenreplikation
- **Zeilenlimit**: 1M Rows per Visual
- **Aggregation**: Auf SQL-Ebene erforderlich

## 📊 View-Hierarchie

### Basis-Layer
```
vw_Dim_* (Dimensionen)
vw_Fact_* (Fakten)
```

### KPI-Layer
```
vw_KPI_* (Geschäftslogik)
```

### Interface-Layer
```
vw_PowerBI_* (Optimiert für Power BI)
```

## 🚨 Kritische Regeln

### Performance
- **NIEMALS**: Direkte Aggregation über appointments-Tabelle (65+ Mio Rows)
- **IMMER**: Materialized Views für schwere Queries
- **BEVORZUGT**: Incremental Updates statt Full Refresh

### Datenqualität
- **KPI-Validierung**: Vor jedem Deployment
- **Plausibilitätsprüfung**: Automatisierte Tests
- **Konsistenzcheck**: Cross-KPI Validierung

### Migration-Phasen
- **🔵 Pre-Migration**: SQL Server Express (aktuell)
- **🟡 Migration**: 3-Wochen-Fenster
- **🟢 Post-Migration**: PostgreSQL (Ziel)