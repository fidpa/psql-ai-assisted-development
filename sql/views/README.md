# PostgreSQL Views

View-Hierarchie für die OrderProcessing.

## Ordner-Struktur
- `01_dim/` - Dimensions-Views (vw_dim_*)
- `02_fact/` - Fakten-Views (vw_fact_*)
- `03_kpi/` - KPI-Calculations-Views (vw_kpi_*)
- `04_powerbi/` - Power BI Interface-Views (vw_powerbi_*)

## Migrations-Reihenfolge
Views müssen in der Ordner-Reihenfolge (01 → 02 → 03 → 04) erstellt werden,
da spätere Views auf frühere Views referenzieren.
