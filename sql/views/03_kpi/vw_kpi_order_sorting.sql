-- =====================================================
-- KPI: OrderSorting
-- Basis fuer kpi_a/kpi_b Calculation
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_OrderSorting (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - EXISTS Subquery bleibt identisch
-- - ISNULL -> COALESCE
-- - Spaltennamen angepasst (lowercase)
--
-- Abhaengigkeiten: vw_fact_order_intake, vw_dim_provider, order_doc
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_order_sorting AS
WITH order_details AS (
    SELECT
        re.intake_date,
        re.count_orders,
        b.is_sentinel,
        b.service_type_id,
        b.do_not_capture_flag,
        b.source_system_id,
        re.provider_id,
        re.invoice_print_date,
        -- Sorting-Logik
        CASE
            -- Ausschluss: Bestimmte ServiceTypes
            WHEN b.service_type_id IN (10, 20, 30, 40) THEN 0
            -- Ausschluss: Bereits elektronisch vorhanden
            WHEN EXISTS (
                SELECT 1 FROM order_doc r
                WHERE r.provider_id = re.provider_id
                  AND r.payout_date = re.invoice_print_date
                  AND r.import_type IN (1, 2) -- WebService, FTP
                  AND COALESCE(r.correction_id, 0) = 0
                  AND r.deleted = 0
            ) THEN 0
            -- Ausschluss: Sentinel
            WHEN b.is_sentinel = 1 THEN 0
            -- Ausschluss: Hat SourceSystem
            WHEN COALESCE(b.source_system_id, 0) > 0 THEN 0
            -- Sonst: Manuell sorting
            ELSE 1
        END AS must_manually_sorted
    FROM vw_fact_order_intake re
    INNER JOIN vw_dim_provider b ON re.provider_id = b.provider_id
)
SELECT
    intake_date,
    SUM(count_orders) AS eingang,
    SUM(CASE WHEN is_sentinel = 1 THEN count_orders ELSE 0 END) AS of_which_sentinel,
    SUM(CASE WHEN must_manually_sorted = 1 THEN count_orders ELSE 0 END) AS sorting
FROM order_details
GROUP BY intake_date;

COMMENT ON VIEW vw_kpi_order_sorting IS
'Basis-KPI fuer Order-Sorting (kpi_a/kpi_b).
Logik: Automatisch = ServiceType IN (10, 20, 30, 40) OR Sentinel OR SourceSystem OR elektronisch vorhanden.
Sorting = Eingang - Automatisch.';
