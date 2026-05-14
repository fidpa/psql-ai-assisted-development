# KPI-Views

KPI-Calculations-Views für die OrderProcessing.

## KPI-Übersicht
| KPI | View | Beschreibung |
|-----|------|-------------|
| kpi_a, kpi_b | vw_kpi_order_intake_kpis | Posteingang |
| S1, S2, S3 | vw_kpi_scanning_aggregated | Scan-Rückstände |
| D0-D4 | vw_kpi_capture_aggregated | Captures-Rückstände |
| V | vw_kpi_expiry | Expiring Orders |
| C1, C2 | vw_kpi_controlling | InsurerInvoices |

## Zentrale Aggregation
- `vw_kpi_dashboard_gesamt` - Kombiniert alle KPIs für Power BI
