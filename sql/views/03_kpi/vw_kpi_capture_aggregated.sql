-- =====================================================
-- KPI: D0-D3 Aggregation (Datencapture)
-- Mit GrossSumn-Schaetzung
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_Capture_Aggregated (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - CAST(GETDATE() AS DATE) -> CURRENT_DATE
-- - ISNULL -> COALESCE
--
-- Abhaengigkeiten: vw_kpi_capture_status_complete
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_capture_aggregated AS
WITH capture_status AS (
    SELECT
        invoice_print_date,
        rest,
        working_days_relative
    FROM vw_kpi_capture_status_complete
),
today_and_future AS (
    SELECT
        invoice_print_date,
        rest,
        working_days_relative,
        -- Fuer D0: Einzelwert kann negativ -> 0
        CASE WHEN rest < 0 THEN 0 ELSE rest END AS remaining_positive
    FROM capture_status
    WHERE invoice_print_date >= CURRENT_DATE
)
SELECT
    -- D0: Wert fuer HEUTE (negativ -> 0)
    COALESCE((
        SELECT remaining_positive
        FROM today_and_future
        WHERE invoice_print_date = CURRENT_DATE
    ), 0) AS d0_heute,

    -- D1: Summe heute + naechste 2 WorkingDays
    CASE
        WHEN (SELECT SUM(rest) FROM today_and_future
              WHERE working_days_relative BETWEEN 0 AND 2) < 0
        THEN 0
        ELSE COALESCE((SELECT SUM(rest) FROM today_and_future
                       WHERE working_days_relative BETWEEN 0 AND 2), 0)
    END AS d1_naechste_3_tage,

    -- D2: Summe heute + naechste 5 WorkingDays
    CASE
        WHEN (SELECT SUM(rest) FROM today_and_future
              WHERE working_days_relative BETWEEN 0 AND 5) < 0
        THEN 0
        ELSE COALESCE((SELECT SUM(rest) FROM today_and_future
                       WHERE working_days_relative BETWEEN 0 AND 5), 0)
    END AS d2_naechste_6_tage,

    -- D3: Summe aller positiven Rest-Werte (nur positive!)
    COALESCE((
        SELECT SUM(remaining_positive)
        FROM today_and_future
    ), 0) AS d3_gesamt,

    -- Geschaetzte GrossSum (TODO: spaeter implementieren)
    0 AS estimated_gross_sum,
    0 AS durchschnitt_pro_order;

COMMENT ON VIEW vw_kpi_capture_aggregated IS
'D-Werte (Datencapture) Aggregation.
D0 = Heute (negativ -> 0).
D1 = Heute + naechste 2 WorkingDays (3 Tage gesamt).
D2 = Heute + naechste 5 WorkingDays (6 Tage gesamt).
D3 = Alle zukuenftigen positiven Rest-Werte.
Negative Summen werden auf 0 gesetzt.';
