-- =====================================================
-- FACT: OrderIntake
-- Basis-Faktentabelle fuer eingehende Orders
-- Beruecksichtigt Datenqualitaet (fehlerhafte Daten)
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Fact_OrderIntake (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - DATEADD(YEAR, 1, GETDATE()) -> CURRENT_DATE + INTERVAL '1 year'
-- - CAST(x AS DATE) -> x::DATE
-- - CONVERT(INT, FORMAT(d, 'yyyyMMdd')) -> TO_CHAR(d, 'YYYYMMDD')::INTEGER
-- - DATEDIFF(DAY, a, b) -> (b::DATE - a::DATE)
--
-- Abhaengigkeiten: Tabelle OrderIntake
-- =====================================================

CREATE OR REPLACE VIEW vw_fact_order_intake AS
SELECT
    -- Primaerschluessel
    re.order_intakeid,

    -- Foreign Keys
    re.provider_id,

    -- Measures
    re.count_orders,

    -- Datumsspalten (bereinigt)
    CASE
        WHEN re.intake_date < '2000-01-01'::DATE
             OR re.intake_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN NULL
        ELSE re.intake_date::DATE
    END AS intake_date,

    CASE
        WHEN re.invoice_print_date < '2000-01-01'::DATE
             OR re.invoice_print_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN NULL
        ELSE re.invoice_print_date::DATE
    END AS invoice_print_date,

    -- Date Keys fuer Joins
    CASE
        WHEN re.intake_date < '2000-01-01'::DATE
             OR re.intake_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN 19000101
        ELSE TO_CHAR(re.intake_date, 'YYYYMMDD')::INTEGER
    END AS intake_date_key,

    CASE
        WHEN re.invoice_print_date < '2000-01-01'::DATE
             OR re.invoice_print_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN 19000101
        ELSE TO_CHAR(re.invoice_print_date, 'YYYYMMDD')::INTEGER
    END AS invoice_print_date_key,

    -- Datenqualitaets-Flags
    CASE
        WHEN re.intake_date < '2000-01-01'::DATE
             OR re.intake_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN 1 ELSE 0
    END AS intake_date_fehlerhaft,

    CASE
        WHEN re.invoice_print_date < '2000-01-01'::DATE
             OR re.invoice_print_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN 1 ELSE 0
    END AS invoice_print_date_fehlerhaft,

    -- Zeitdifferenz fuer Analysen
    (re.invoice_print_date::DATE - re.intake_date::DATE) AS tage_zwischen_eingang_und_druck

FROM order_intake re
WHERE re.count_orders > 0  -- Nur sinnvolle Eintraege
  AND re.provider_id IS NOT NULL;

COMMENT ON VIEW vw_fact_order_intake IS
'OrderIntake-Faktentabelle mit Datenqualitaetspruefung.
Fehlerhafte Daten (vor 2000 oder >1 Jahr in Zukunft) werden als NULL/19000101 markiert.';
