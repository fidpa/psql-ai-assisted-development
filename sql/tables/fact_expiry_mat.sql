-- =====================================================
-- MATERIALIZED VIEW: fact_expiry_mat
-- Performance-optimierte Expirydaten
-- Version: 1.0 (PostgreSQL)
-- =====================================================
--
-- Diese Materialized View ersetzt die SQL Server Loesung
-- mit manualer Tabelle + Stored Procedure.
--
-- PostgreSQL Vorteile:
-- - REFRESH MATERIALIZED VIEW CONCURRENTLY (ohne Locks)
-- - Automatische Indexierung moeglich
-- - Einfachere Wartung als manuale Tabelle
--
-- Abhaengigkeiten: vw_fact_expiry_calculation
-- =====================================================

-- Materialized View erstellen
CREATE MATERIALIZED VIEW IF NOT EXISTS fact_expiry_mat AS
SELECT
    order_id,
    provider_id,
    customer_id,
    counterparty_id,
    invoice_insurer_id,
    capture_date,
    payout_date,
    last_service_date,
    event_count,
    expired_at,
    days_until_expiry,
    expiry_status,
    deleted,
    order_id_deleted,
    exported,
    correction_id,
    import_type,
    ohne_insurer_invoice
FROM vw_fact_expiry_calculation;

-- =====================================================
-- INDIZES fuer schnelle Abfragen
-- =====================================================

-- Primaer-Lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_fact_expiry_mat_order_id
    ON fact_expiry_mat(order_id);

-- Provider-Analysen
CREATE INDEX IF NOT EXISTS idx_fact_expiry_mat_provider_id
    ON fact_expiry_mat(provider_id);

-- Status-Filterung (fuer KPI-Views)
CREATE INDEX IF NOT EXISTS idx_fact_expiry_mat_status
    ON fact_expiry_mat(expiry_status);

-- Tage bis Expiry (fuer kritische Faelle)
CREATE INDEX IF NOT EXISTS idx_fact_expiry_mat_tage
    ON fact_expiry_mat(days_until_expiry)
    WHERE days_until_expiry BETWEEN 0 AND 60;

-- Ohne InsurerInvoice (fuer D4 KPI)
CREATE INDEX IF NOT EXISTS idx_fact_expiry_mat_ohne_kr
    ON fact_expiry_mat(ohne_insurer_invoice)
    WHERE ohne_insurer_invoice = 1;

-- Composite Index fuer haeufige Filter-Kombination
CREATE INDEX IF NOT EXISTS idx_fact_expiry_mat_filter
    ON fact_expiry_mat(exported, deleted, correction_id);

-- =====================================================
-- KOMMENTAR
-- =====================================================

COMMENT ON MATERIALIZED VIEW fact_expiry_mat IS
'Materialisierte Expirydaten fuer Performance.
Basiert auf vw_fact_expiry_calculation.
Refresh: REFRESH MATERIALIZED VIEW CONCURRENTLY fact_expiry_mat;
Empfohlen: Taeglich per pg_cron oder externem Scheduler.';

-- =====================================================
-- REFRESH FUNKTION (optional, fuer einfache Aufrufe)
-- =====================================================

CREATE OR REPLACE FUNCTION fn_refresh_expiry_mat()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    row_count INTEGER;
BEGIN
    start_time := clock_timestamp();

    -- CONCURRENTLY erlaubt Lesezugriff waehrend Refresh
    -- Benoetigt UNIQUE INDEX (idx_fact_expiry_mat_order_id)
    REFRESH MATERIALIZED VIEW CONCURRENTLY fact_expiry_mat;

    end_time := clock_timestamp();

    SELECT COUNT(*) INTO row_count FROM fact_expiry_mat;

    RETURN format('Refresh erfolgreich: %s Zeilen in %s',
                  row_count,
                  (end_time - start_time)::TEXT);
END;
$$;

COMMENT ON FUNCTION fn_refresh_expiry_mat() IS
'Aktualisiert fact_expiry_mat mit CONCURRENTLY Option.
Aufruf: SELECT fn_refresh_expiry_mat();
Gibt Zeilencount und Dauer zurueck.';

-- =====================================================
-- WRAPPER VIEW AKTUALISIEREN
-- =====================================================
-- Die vw_fact_expiry sollte nun auf die Mat-View zeigen.
-- Dazu vw_fact_expiry.sql anpassen:
--
-- CREATE OR REPLACE VIEW vw_fact_expiry AS
-- SELECT * FROM fact_expiry_mat;
--
-- =====================================================

-- =====================================================
-- SCHEDULING (pg_cron Extension, falls installiert)
-- =====================================================
-- -- Taeglich um 05:00 Uhr refreshen:
-- SELECT cron.schedule('refresh_expiry', '0 5 * * *',
--     'SELECT fn_refresh_expiry_mat()');
--
-- -- Status pruefen:
-- SELECT * FROM cron.job;
--
-- -- Job entfernen:
-- SELECT cron.unschedule('refresh_expiry');
-- =====================================================

-- =====================================================
-- VALIDIERUNG (nach Installation ausfuehren)
-- =====================================================
--
-- -- Zeilencount pruefen:
-- SELECT COUNT(*) FROM fact_expiry_mat;
--
-- -- Expiry-Verteilung:
-- SELECT expiry_status, COUNT(*)
-- FROM fact_expiry_mat
-- GROUP BY expiry_status
-- ORDER BY COUNT(*) DESC;
--
-- -- Kritische Faelle (<=20 Tage):
-- SELECT COUNT(*)
-- FROM fact_expiry_mat
-- WHERE days_until_expiry BETWEEN 0 AND 20;
--
-- -- D4 KPI Test:
-- SELECT COUNT(*)
-- FROM fact_expiry_mat
-- WHERE ohne_insurer_invoice = 1
--   AND days_until_expiry > 0
--   AND expired_at <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
-- =====================================================
