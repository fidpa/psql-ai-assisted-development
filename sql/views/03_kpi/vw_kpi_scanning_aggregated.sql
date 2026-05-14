-- =====================================================
-- KPI: S1, S2, S3 Aggregation (Scanning-Backlog)
-- Summiert Scan-Backlog fuer verschiedene Zeitraeume
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_Scanning_Aggregated (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - CAST(GETDATE() AS DATE) -> CURRENT_DATE
-- - ISNULL -> COALESCE
--
-- Abhaengigkeiten: vw_kpi_capture_status_complete
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_scanning_aggregated AS
WITH scanstand AS (
    SELECT
        invoice_print_date,
        pending_scan,
        working_days_relative
    FROM vw_kpi_capture_status_complete
    WHERE invoice_print_date > CURRENT_DATE  -- NUR ZUKUNFT fuer S-Werte!
)
SELECT
    -- S1: OHNE heute! Nur die naechsten 3 Tage
    CASE
        WHEN (SELECT SUM(pending_scan) FROM scanstand
              WHERE working_days_relative BETWEEN 1 AND 3) < 0
        THEN 0
        ELSE COALESCE((SELECT SUM(pending_scan) FROM scanstand
                       WHERE working_days_relative BETWEEN 1 AND 3), 0)
    END AS s1_naechste_3_tage,

    -- S2: Die naechsten 6 Tage
    CASE
        WHEN (SELECT SUM(pending_scan) FROM scanstand
              WHERE working_days_relative BETWEEN 1 AND 6) < 0
        THEN 0
        ELSE COALESCE((SELECT SUM(pending_scan) FROM scanstand
                       WHERE working_days_relative BETWEEN 1 AND 6), 0)
    END AS s2_naechste_6_tage,

    -- S3: Alle zukuenftigen positiven Werte
    COALESCE((
        SELECT SUM(CASE WHEN pending_scan > 0 THEN pending_scan ELSE 0 END)
        FROM scanstand
    ), 0) AS s3_gesamt,

    0 AS erster_tag_mit_backlog,
    0 AS count_tage_mit_backlog;

COMMENT ON VIEW vw_kpi_scanning_aggregated IS
'S-Werte (Scanning-Backlog) Aggregation.
S1 = Naechste 3 WorkingDays (ohne heute).
S2 = Naechste 6 WorkingDays.
S3 = Alle zukuenftigen positiven Werte.
Negative Summen werden auf 0 gesetzt.';
