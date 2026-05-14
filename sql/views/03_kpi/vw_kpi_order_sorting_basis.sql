-- =====================================================
-- KPI: OrderSorting Basis (Detail)
-- Ermittelt welche Orders manual sortiert werden muessen
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_OrderSorting_Basis (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - DATEADD(MONTH, -3, GETDATE()) -> CURRENT_DATE - INTERVAL '3 months'
-- - ISNULL -> COALESCE
-- - Spaltennamen angepasst (lowercase)
--
-- Abhaengigkeiten: vw_fact_order_intake, vw_dim_provider, vw_fact_order
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_order_sorting_basis AS
WITH elektronisch_vorhanden AS (
    -- Computation fuer bessere Performance
    SELECT DISTINCT
        r.provider_id,
        r.payout_date,
        1 AS is_elektronisch_vorhanden
    FROM vw_fact_order r
    WHERE r.import_type IN (1, 2)  -- FTP, WebService
      AND COALESCE(r.correction_id, 0) = 0
      AND r.deleted = 0
      AND r.is_gueltiges_order = 1
)
SELECT
    re.intake_date,
    re.provider_id,
    b.customer_no,
    b.company_name,
    re.count_orders,
    b.is_sentinel,
    b.service_type_id,
    b.sorting_category,

    -- Muss manual sortiert werden?
    CASE
        WHEN b.must_be_manually_sorted = 0 THEN 0  -- Bereits in Dimension berechnet
        WHEN ev.is_elektronisch_vorhanden = 1 THEN 0
        ELSE re.count_orders
    END AS count_zu_sorting,

    -- Detail-Grund
    CASE
        WHEN b.service_type_id IN (10, 20, 30, 40) THEN 'Automatischer ServiceType'
        WHEN b.is_sentinel = 1 THEN 'Sentinel'
        WHEN b.has_source_system = 1 THEN 'Hat SourceSystem'
        WHEN b.do_not_capture_flag = 1 THEN 'DoNotCapture'
        WHEN ev.is_elektronisch_vorhanden = 1 THEN 'Bereits elektronisch'
        ELSE 'Manuell sorting'
    END AS sortier_grund

FROM vw_fact_order_intake re
INNER JOIN vw_dim_provider b ON re.provider_id = b.provider_id
LEFT JOIN elektronisch_vorhanden ev
    ON re.provider_id = ev.provider_id
    AND re.invoice_print_date = ev.payout_date
WHERE re.intake_date_fehlerhaft = 0  -- Nur valide Daten
  AND re.intake_date >= (CURRENT_DATE - INTERVAL '3 months');  -- Performance: nur letzte 3 Monate

COMMENT ON VIEW vw_kpi_order_sorting_basis IS
'Detail-View fuer Sorting-Logik mit Grund-Angabe.
Nur Daten der letzten 3 Monate fuer Performance.
Sorting-Gruende: Automatischer ServiceType, Sentinel, SourceSystem, Nicht capture, Bereits elektronisch, Manuell sorting.';
