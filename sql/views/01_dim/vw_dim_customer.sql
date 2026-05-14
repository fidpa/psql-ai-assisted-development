-- =====================================================
-- DIMENSION: Customer
-- CustomerMasterData fuer Analysen
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Dim_Customer (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - + (String-Concat) -> ||
-- - LEFT(x, 1) -> LEFT(x, 1) (identisch)
-- - UPPER -> UPPER (identisch)
-- - RIGHT('00000' + CAST(x AS VARCHAR), 6) -> LPAD(x::TEXT, 6, '0')
--
-- Abhaengigkeiten: Tabelle Customer
-- =====================================================

CREATE OR REPLACE VIEW vw_dim_customer AS
SELECT
    -- Primaerschluessel
    p.customer_id,

    -- MasterData
    p.last_name,
    p.first_name,
    p.last_name || ', ' || p.first_name AS full_name,

    -- Abgeleitete Felder fuer Gruppierungen
    UPPER(LEFT(p.last_name, 1)) AS leading_letter,

    -- Stable analytics-safe surrogate key
    'CUST-' || LPAD(p.customer_id::TEXT, 6, '0') AS customer_code

FROM customer p;

COMMENT ON VIEW vw_dim_customer IS
'Customer dimension exposing a stable surrogate key (customer_code) suitable for analytics joins.';
