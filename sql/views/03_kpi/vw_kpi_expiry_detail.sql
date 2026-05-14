-- =====================================================
-- KPI: Expiry Detail fuer Drill-Down
-- Zeigt kritische Faelle nach Provider
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_Expiry_Detail (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - STRING_AGG(...) WITHIN GROUP (ORDER BY ...) -> STRING_AGG(... ORDER BY ...)
-- - CAST(x AS VARCHAR(10)) -> x::TEXT
--
-- Abhaengigkeiten: vw_fact_expiry, vw_dim_provider
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_expiry_detail AS
SELECT
    v.provider_id,
    b.customer_no,
    b.company_name,
    v.expiry_status,
    COUNT(*) AS count_orders,
    MIN(v.days_until_expiry) AS min_days_until_expiry,
    MAX(v.days_until_expiry) AS max_days_until_expiry,
    COUNT(CASE WHEN v.ohne_insurer_invoice = 1 THEN 1 END) AS without_insurer_invoice_count,
    STRING_AGG(
        CASE
            WHEN v.days_until_expiry <= 10
            THEN v.order_id::TEXT
            ELSE NULL
        END,
        ', '
        ORDER BY v.days_until_expiry
    ) AS kritische_order_ids
FROM vw_fact_expiry v
INNER JOIN vw_dim_provider b ON v.provider_id = b.provider_id
WHERE v.days_until_expiry BETWEEN 0 AND 30  -- Nur kritische
  AND v.exported = 0
  AND v.deleted = 0
GROUP BY
    v.provider_id,
    b.customer_no,
    b.company_name,
    v.expiry_status
HAVING COUNT(*) > 0;

COMMENT ON VIEW vw_kpi_expiry_detail IS
'Detail-View fuer Expiry-Drill-Down nach Provider.
Nur kritische Faelle (0-30 Tage bis Expiry).
kritische_order_ids = OrderIDs mit <= 10 Tagen bis Expiry.';
