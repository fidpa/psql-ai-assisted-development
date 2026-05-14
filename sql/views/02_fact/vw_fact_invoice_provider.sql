-- =====================================================
-- FACT: InvoiceProvider
-- Fuer Durchschnittsbeinvoiceen der GrossSumn
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Fact_InvoiceProvider (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - Korrelierte Subqueries bleiben identisch
-- - COALESCE statt Division-by-zero Check (PostgreSQL-idiomatisch)
--
-- Abhaengigkeiten: Tabellen InvoiceProvider, Order
-- =====================================================

CREATE OR REPLACE VIEW vw_fact_invoice_provider AS
SELECT
    rb.invoice_provider_id,
    rb.provider_id,
    rb.gross_amount,

    -- Anzahl zugeordneter Orders
    (SELECT COUNT(*)
     FROM order_doc r
     WHERE r.invoice_provider_id = rb.invoice_provider_id
       AND r.deleted = 0
       AND COALESCE(r.correction_id, 0) = 0
    ) AS count_orders,

    -- Durchschnittlicher GrossAmount pro Order
    CASE
        WHEN (SELECT COUNT(*)
              FROM order_doc r
              WHERE r.invoice_provider_id = rb.invoice_provider_id
                AND r.deleted = 0
                AND COALESCE(r.correction_id, 0) = 0) > 0
        THEN rb.gross_amount / (SELECT COUNT(*)
                                FROM order_doc r
                                WHERE r.invoice_provider_id = rb.invoice_provider_id
                                  AND r.deleted = 0
                                  AND COALESCE(r.correction_id, 0) = 0)
        ELSE 0
    END AS durchschnitt_pro_order

FROM invoice_provider rb
WHERE rb.gross_amount > 0;

COMMENT ON VIEW vw_fact_invoice_provider IS
'InvoiceProvider-Faktentabelle mit Order-Anzahl und Durchschnittsbeinvoice.
Nur Invoiceen mit BruttoBetrag > 0.
Orders: Nur nicht-deleted, nicht-korrigierte.';

-- =====================================================
-- Performance-Optimierung (optional):
-- Bei grossen Datenmengen kann die View mit Subqueries
-- durch eine JOIN-basierte Version ersetzt werden:
-- =====================================================
--
-- CREATE OR REPLACE VIEW vw_fact_invoice_provider_optimized AS
-- WITH order_counts AS (
--     SELECT
--         invoice_provider_id,
--         COUNT(*) AS count_orders
--     FROM order_doc
--     WHERE deleted = 0
--       AND COALESCE(correction_id, 0) = 0
--     GROUP BY invoice_provider_id
-- )
-- SELECT
--     rb.invoice_provider_id,
--     rb.provider_id,
--     rb.gross_amount,
--     COALESCE(rc.count_orders, 0) AS count_orders,
--     CASE
--         WHEN COALESCE(rc.count_orders, 0) > 0
--         THEN rb.gross_amount / rc.count_orders
--         ELSE 0
--     END AS durchschnitt_pro_order
-- FROM invoice_provider rb
-- LEFT JOIN order_counts rc ON rb.invoice_provider_id = rc.invoice_provider_id
-- WHERE rb.gross_amount > 0;
