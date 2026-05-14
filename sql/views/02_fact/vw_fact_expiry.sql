-- =====================================================
-- FACT: Expiry (Wrapper fuer Materialized View)
-- Zentrale Expirydaten fuer KPI-Calculationen
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Fact_Expiry (SQL Server)
-- =====================================================
--
-- ARCHITEKTUR:
-- 1. vw_fact_expiry_calculation - Berechnende View (langsam, aktuell)
-- 2. fact_expiry_mat - Materialized View (schnell, muss refreshed werden)
-- 3. vw_fact_expiry - Diese Wrapper-View (zeigt auf Materialized View)
--
-- PostgreSQL Vorteil: MATERIALIZED VIEW statt manualer Tabelle + Stored Proc
--
-- Abhaengigkeiten: fact_expiry_mat (Materialized View)
-- =====================================================

-- PRODUKTION: Verwendet Materialized View fuer Performance
-- Bewusster Pass-through-Wrapper. Spalten ergeben sich aus fact_expiry_mat;
-- eine explizite Liste wuerde das Schema duplizieren.
CREATE OR REPLACE VIEW vw_fact_expiry AS
SELECT * FROM fact_expiry_mat;  -- noqa: AM04

-- =====================================================
-- ENTWICKLUNG/TESTING: Direkter Zugriff auf Calculation
-- Falls Materialized View nicht existiert, diese Version verwenden:
-- =====================================================
-- CREATE OR REPLACE VIEW vw_fact_expiry AS
-- SELECT
--     order_id,
--     provider_id,
--     customer_id,
--     counterparty_id,
--     invoice_insurer_id,
--     capture_date,
--     payout_date,
--     last_service_date,
--     event_count,
--     expired_at,
--     days_until_expiry,
--     expiry_status,
--     deleted,
--     order_id_deleted,
--     exported,
--     correction_id,
--     import_type,
--     ohne_insurer_invoice
-- FROM vw_fact_expiry_calculation;

COMMENT ON VIEW vw_fact_expiry IS
'Wrapper-View fuer Expirydaten.
In Produktion: SELECT * FROM fact_expiry_mat (schnell)
In Entwicklung: SELECT * FROM vw_fact_expiry_calculation (langsam, aktuell)
Refresh: REFRESH MATERIALIZED VIEW fact_expiry_mat;';

-- =====================================================
-- MATERIALIZED VIEW (separat ausfuehren in Produktion)
-- =====================================================
-- CREATE MATERIALIZED VIEW fact_expiry_mat AS
-- SELECT * FROM vw_fact_expiry_calculation;
--
-- -- Index fuer schnelle Lookups
-- CREATE INDEX idx_fact_expiry_mat_order_id
--     ON fact_expiry_mat(order_id);
-- CREATE INDEX idx_fact_expiry_mat_provider_id
--     ON fact_expiry_mat(provider_id);
-- CREATE INDEX idx_fact_expiry_mat_status
--     ON fact_expiry_mat(expiry_status);
--
-- -- Refresh-Befehl (taeglich oder nach Bedarf):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY fact_expiry_mat;
-- =====================================================
