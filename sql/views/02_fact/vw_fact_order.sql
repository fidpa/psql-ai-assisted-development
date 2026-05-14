-- =====================================================
-- FACT: Order
-- Zentrale Faktentabelle fuer Orders
-- Mit Cleanup der Datenqualitaetsprobleme
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Fact_Order (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - DATEADD(YEAR, 1, GETDATE()) -> CURRENT_DATE + INTERVAL '1 year'
-- - CAST(x AS DATE) -> x::DATE
-- - CONVERT(INT, FORMAT(d, 'yyyyMMdd')) -> TO_CHAR(d, 'YYYYMMDD')::INTEGER
-- - ISNULL(x, 0) -> COALESCE(x, 0)
-- - + (String-Concat) -> ||
--
-- Abhaengigkeiten: Tabellen Order, ImportFehler
-- =====================================================

CREATE OR REPLACE VIEW vw_fact_order AS
SELECT
    -- Primaerschluessel
    r.order_id,

    -- Foreign Keys
    r.provider_id,
    r.customer_id,
    r.counterparty_id,
    r.invoice_provider_id,
    r.invoice_insurer_id,
    r.invoice_customer_id,

    -- Datumsspalten (bereinigt)
    CASE
        WHEN r.payout_date < '2000-01-01'::DATE
             OR r.payout_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN NULL
        ELSE r.payout_date::DATE
    END AS payout_date,

    CASE
        WHEN r.capture_date < '2000-01-01'::DATE
             OR r.capture_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN NULL
        ELSE r.capture_date::DATE
    END AS capture_date,

    -- Date Keys
    CASE
        WHEN r.payout_date < '2000-01-01'::DATE
             OR r.payout_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN 19000101
        ELSE TO_CHAR(r.payout_date, 'YYYYMMDD')::INTEGER
    END AS auszahlungsdate_key,

    CASE
        WHEN r.capture_date < '2000-01-01'::DATE
             OR r.capture_date > (CURRENT_DATE + INTERVAL '1 year')
        THEN 19000101
        ELSE TO_CHAR(r.capture_date, 'YYYYMMDD')::INTEGER
    END AS capture_date_key,

    -- ImportType mit Bezeichnung
    r.import_type,
    CASE r.import_type
        WHEN 0 THEN 'Manual'
        WHEN 10 THEN 'Scan'
        WHEN 2 THEN 'Correction'
        WHEN 3 THEN 'Legacy'
        WHEN 4 THEN 'Channel_B'
        WHEN 20 THEN 'Historic'
        WHEN 6 THEN 'Channel_C'
        WHEN 7 THEN 'Channel_D'
        ELSE 'Unknown (' || r.import_type::TEXT || ')'
    END AS import_type_label,

    -- Status-Flags
    r.exported,
    r.in_progress,
    r.deleted,
    COALESCE(r.correction_id, 0) AS correction_id,
    CASE WHEN COALESCE(r.correction_id, 0) > 0 THEN 1 ELSE 0 END AS is_correction,
    r.altid,
    r.order_id_deleted,
    CASE WHEN r.order_id_deleted > 0 THEN 1 ELSE 0 END AS has_deleted_version,

    -- Klassifizierung fuer Geschaeftslogik
    CASE
        WHEN r.deleted = 1 THEN 'Deleted'
        WHEN r.order_id_deleted > 0 THEN 'Hat deleted Version'
        WHEN COALESCE(r.correction_id, 0) > 0 THEN 'Correction'
        WHEN r.in_progress = 1 THEN 'In progress'
        WHEN r.exported = 1 THEN 'exported'
        ELSE 'Aktiv'
    END AS order_status,

    -- Hilfsspalten fuer Filterung
    CASE
        WHEN r.deleted = 0
         AND COALESCE(r.correction_id, 0) = 0
         AND r.in_progress = 0
         AND r.order_id NOT IN (SELECT order_id FROM importfehler)
        THEN 1
        ELSE 0
    END AS is_gueltiges_order

FROM order_doc r
-- Basis-Filter fuer offensichtlich fehlerhafte Daten
WHERE r.provider_id IS NOT NULL
  AND r.provider_id > 0;

COMMENT ON VIEW vw_fact_order IS
'Zentrale Order-Faktentabelle mit Datenqualitaetspruefung und Status-Klassifizierung.
ImportType: 0=Manual, 1=Scan, 2=Correction, 3=Legacy, 4=Channel_B, 5=Historic, 6=Channel_C, 7=Channel_D.
is_gueltiges_order=1 fuer nicht-deleted, nicht-korrigierte, nicht-in-bearbeitung Orders ohne ImportFehler.';
