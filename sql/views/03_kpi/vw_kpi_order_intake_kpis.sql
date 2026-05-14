-- =====================================================
-- KPI: kpi_a und kpi_b Calculation
-- kpi_a = OrderIntake vom letzten Arbeitstag
-- kpi_b = Summe der letzten 3 WorkingDays
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_OrderIntake_KPIs (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - [Date] -> datum
-- - ISNULL -> COALESCE
-- - Window Functions bleiben identisch
--
-- Abhaengigkeiten: vw_dim_working_days, vw_kpi_order_sorting
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_order_intake_kpis AS
WITH working_days_data AS (
    SELECT
        a.datum,
        a.working_days_relative_to_today,
        COALESCE(r.sorting, 0) AS sorting
    FROM vw_dim_working_days a
    LEFT JOIN vw_kpi_order_sorting r ON a.datum = r.intake_date
    WHERE a.working_days_relative_to_today BETWEEN -30 AND -1 -- Letzte 30 WorkingDays
)
SELECT
    datum,
    working_days_relative_to_today,
    sorting,
    -- kpi_a: Wert vom vorherigen Arbeitstag
    LAG(sorting, 1, 0) OVER (ORDER BY datum) AS e1_vorheriger_tag,
    -- kpi_b: Summe der letzten 3 WorkingDays
    SUM(sorting) OVER (
        ORDER BY datum
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS e2_letzte_3_tage
FROM working_days_data;

COMMENT ON VIEW vw_kpi_order_intake_kpis IS
'kpi_a/kpi_b KPI-Calculation mit Window Functions.
kpi_a = Sorting-Wert vom letzten Arbeitstag (LAG).
kpi_b = Summe Sorting der letzten 3 WorkingDays (Rolling Window).
Nur vergangene 30 WorkingDays beruecksichtigt.';
