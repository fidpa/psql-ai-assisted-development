-- =====================================================
-- FACT: Expiry Calculation
-- Calculation der Expirydaten basierend auf appointments
-- BERECHNENDE View - wird fuer Materialisierung verwendet
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Fact_Expiry_Calculation (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - GETDATE() -> CURRENT_DATE
-- - DATEADD(DAY, 180, d) -> d + INTERVAL '180 days'
-- - DATEDIFF(DAY, GETDATE(), d) -> (d::DATE - CURRENT_DATE)
-- - CAST(d AS DATE) -> d::DATE
--
-- Abhaengigkeiten:
-- - vw_fact_order
-- - Tabellen: Order, OrderLineItem, Appointment, Counterparty
--
-- Performance-Hinweis:
-- Diese View berechnet ueber 65 Mio. appointments.
-- In Produktion sollte das Ergebnis materialisiert werden.
-- =====================================================

CREATE OR REPLACE VIEW vw_fact_expiry_calculation AS
WITH last_service_date AS (
    -- Computation of the last service_date pro Order
    -- Nutzt Aggregation fuer bessere Performance
    SELECT
        rl.order_id,
        MAX(t.datum::DATE) AS last_service_date,
        COUNT(t.event_id) AS event_count
    FROM order_line rl
    INNER JOIN appointment t ON rl.order_line_id = t.order_line_id
    WHERE t.datum IS NOT NULL
      AND t.datum >= '2000-01-01'::DATE  -- Plausibilitaetspruefung
      AND t.datum <= CURRENT_DATE
    GROUP BY rl.order_id
)
SELECT
    fr.order_id,
    fr.provider_id,
    fr.customer_id,
    fr.counterparty_id,
    r.invoice_insurer_id,

    -- Datumsinformationen
    fr.capture_date,
    fr.payout_date,
    lbd.last_service_date,
    lbd.event_count,

    -- Expiration (180 days after the reference event)
    (lbd.last_service_date + INTERVAL '180 days')::DATE AS expired_at,

    -- Tage bis zur Expiry
    ((lbd.last_service_date + INTERVAL '180 days')::DATE - CURRENT_DATE) AS days_until_expiry,

    -- Expirystatus
    CASE
        WHEN (lbd.last_service_date + INTERVAL '180 days')::DATE < CURRENT_DATE
            THEN 'Bereits expired'
        WHEN ((lbd.last_service_date + INTERVAL '180 days')::DATE - CURRENT_DATE) <= 20
            THEN 'Kritisch (<=20 Tage)'
        WHEN ((lbd.last_service_date + INTERVAL '180 days')::DATE - CURRENT_DATE) <= 30
            THEN 'Warnung (<=30 Tage)'
        WHEN ((lbd.last_service_date + INTERVAL '180 days')::DATE - CURRENT_DATE) <= 60
            THEN 'Beobachten (<=60 Tage)'
        ELSE 'Unkritisch'
    END AS expiry_status,

    -- Flags aus Order
    fr.deleted,
    fr.order_id_deleted,
    fr.exported,
    fr.correction_id,
    fr.import_type,

    -- Flag fuer D4 KPI
    CASE
        WHEN r.invoice_insurer_id IS NULL THEN 1
        ELSE 0
    END AS ohne_insurer_invoice

FROM vw_fact_order fr
INNER JOIN order_doc r ON fr.order_id = r.order_id  -- Fuer InvoiceInsurerID
INNER JOIN last_service_date lbd ON r.order_id = lbd.order_id
-- Nur relevante Orders fuer Expiry
WHERE fr.is_gueltiges_order = 1
  AND fr.exported = 0
  AND (fr.counterparty_id IS NULL OR fr.counterparty_id NOT IN (
      SELECT counterparty_id FROM counterparty WHERE account_class = 'retail'
  ));

COMMENT ON VIEW vw_fact_expiry_calculation IS
'Berechnende View fuer Expirydaten - Performance-intensiv!
Expiry: 180 days after the reference event.
Status: Kritisch (<=20 Tage), Warnung (<=30 Tage), Beobachten (<=60 Tage).
Diese View sollte materialisiert werden (siehe fact_expiry_mat).';
