-- =====================================================
-- KPI: CaptureStatus Komplett
-- Basis fuer S-Werte (Scanning) und D-Werte (Datencapture)
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_CaptureStatus_Complete (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - CAST(GETDATE() AS DATE) -> CURRENT_DATE
-- - ISNULL(x, 0) -> COALESCE(x, 0)
-- - TOP 1 -> LIMIT 1
-- - [Date] -> datum
-- - Korrelierte Subqueries bleiben aehnlich
--
-- Abhaengigkeiten:
-- - vw_fact_order_intake
-- - vw_dim_provider
-- - vw_dim_working_days
-- - order_doc, counterparty
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_capture_status_complete AS
WITH basisdaten AS (
    SELECT
        re.intake_date,
        re.invoice_print_date,  -- Das ist "bis zum ... drucken"!
        re.provider_id,
        re.count_orders,
        b.is_sentinel,
        b.service_type_id,
        b.source_system_id,
        b.do_not_capture_flag,

        -- "manual capture" Spalte (aus C# Logik)
        CASE
            WHEN b.service_type_id IN (10, 20, 30, 40) THEN 0
            WHEN EXISTS (
                SELECT 1 FROM order_doc r
                WHERE r.provider_id = re.provider_id
                  AND r.payout_date = re.invoice_print_date
                  AND r.import_type IN (1, 2)  -- FTP, WebService
                  AND COALESCE(r.correction_id, 0) = 0
                  AND r.deleted = 0
                  AND CASE
                      WHEN r.counterparty_id = (SELECT counterparty_id FROM counterparty WHERE account_class = 'retail' LIMIT 1)
                      THEN CASE WHEN COALESCE(r.invoice_customer_id, 0) <> 1 THEN 1 ELSE 0 END
                      ELSE CASE WHEN COALESCE(r.invoice_insurer_id, 0) <> 1 THEN 1 ELSE 0 END
                  END = 1
            ) THEN 0
            WHEN b.is_sentinel = 1 THEN 0  -- Sentinel wird nicht manual erfasst
            WHEN COALESCE(b.source_system_id, 0) > 0 THEN 0
            WHEN b.do_not_capture_flag = 1 THEN 0
            ELSE re.count_orders
        END AS manual_capture,

        -- "Fertig" Spalte
        COALESCE((
            SELECT COUNT(*)
            FROM order_doc r
            WHERE r.provider_id = re.provider_id
              AND r.payout_date = re.invoice_print_date
              AND r.in_progress = 0
              AND r.deleted = 0
              AND COALESCE(r.correction_id, 0) = 0
              AND CASE
                  WHEN r.counterparty_id = (SELECT counterparty_id FROM counterparty WHERE account_class = 'retail' LIMIT 1)
                  THEN CASE WHEN COALESCE(r.invoice_customer_id, 0) <> 1 THEN 1 ELSE 0 END
                  ELSE CASE WHEN COALESCE(r.invoice_insurer_id, 0) <> 1 THEN 1 ELSE 0 END
              END = 1
        ), 0) AS fertig,

        -- "Deleted" = Returned
        COALESCE((
            SELECT COUNT(*)
            FROM order_doc r
            WHERE r.provider_id = re.provider_id
              AND r.payout_date = re.invoice_print_date
              AND r.deleted = 1
              AND COALESCE(r.correction_id, 0) = 0
        ), 0) AS deleted,

        -- "Gescans" fuer "vom Rest noch zu scanning"
        COALESCE((
            SELECT COUNT(*)
            FROM order_doc r
            WHERE r.provider_id = re.provider_id
              AND r.payout_date = re.invoice_print_date
              AND r.import_type IN (0, 1)  -- Manuell + Scanner (aus C# Code!)
              AND r.deleted = 0
        ), 0) AS gescans

    FROM vw_fact_order_intake re
    INNER JOIN vw_dim_provider b ON re.provider_id = b.provider_id
    WHERE re.invoice_print_date_fehlerhaft = 0
),
aggregiert AS (
    SELECT
        invoice_print_date,
        MIN(intake_date) AS from_date,
        MAX(CASE WHEN MIN(intake_date) = MAX(intake_date) THEN NULL ELSE intake_date END) AS to_date,
        SUM(count_orders) AS eingang,
        SUM(CASE WHEN is_sentinel = 1 THEN count_orders ELSE 0 END) AS of_which_sentinel,
        SUM(manual_capture) AS manual_capture,
        SUM(fertig) AS fertig,
        SUM(deleted) AS returned,
        -- "Rest" Spalte (kann negativ sein!)
        SUM(manual_capture) - SUM(deleted) - SUM(fertig) AS rest,
        -- "vom Rest noch zu scanning" (kann negativ sein!)
        SUM(manual_capture) - SUM(deleted) - SUM(gescans) AS pending_scan
    FROM basisdaten
    GROUP BY invoice_print_date
)
SELECT
    ag.*,
    -- WorkingDays-Differenz zu heute
    COALESCE(a.working_days_relative_to_today,
        CASE
            WHEN ag.invoice_print_date < CURRENT_DATE THEN -999
            WHEN ag.invoice_print_date = CURRENT_DATE THEN 0
            ELSE 999
        END
    ) AS working_days_relative
FROM aggregiert ag
LEFT JOIN vw_dim_working_days a ON ag.invoice_print_date = a.datum;

COMMENT ON VIEW vw_kpi_capture_status_complete IS
'Kompletter CaptureStatus pro Druckdatum.
Basis fuer S-Werte (pending_scan) und D-Werte (rest).
Negative Werte moeglich bei mehr fertig/gescans als erwartet.
working_days_relative: -999=Vergangenheit ohne Arbeitstag, 0=heute, 999=Zukunft ohne Arbeitstag.';
