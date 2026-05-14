-- =====================================================
-- DIMENSION: Invoicekasse
-- Dimensionstabelle fuer InsurerInvoices
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Dim_InvoiceInsurer (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - CAST(x AS DATE) -> x::DATE
-- - YEAR(x) -> EXTRACT(YEAR FROM x)::INTEGER
-- - MONTH(x) -> EXTRACT(MONTH FROM x)::INTEGER
-- - DATEPART(QUARTER, x) -> EXTRACT(QUARTER FROM x)::INTEGER
-- - DATEDIFF(DAY, x, y) -> (y::DATE - x::DATE)
-- - GETDATE() -> CURRENT_DATE
-- - ISNULL -> COALESCE
-- - + (String-Concat) -> ||
--
-- Abhaengigkeiten: Tabelle InvoiceInsurer
-- =====================================================

CREATE OR REPLACE VIEW vw_dim_invoice_insurer AS
SELECT
    -- Primaerschluessel
    rk.invoice_insurer_id,

    -- Invoicedaten
    rk.rnr AS invoicesnummer,
    rk.datum::DATE AS invoice_date,
    EXTRACT(YEAR FROM rk.datum)::INTEGER AS invoice_jahr,
    EXTRACT(MONTH FROM rk.datum)::INTEGER AS invoice_month,
    EXTRACT(QUARTER FROM rk.datum)::INTEGER AS invoice_quartal,

    -- Status (wichtig fuer C1 KPI)
    rk.status,
    CASE rk.status
        WHEN 10 THEN 'Neu/Unbestaetigt'
        WHEN 2 THEN 'Bestaetigt'
        WHEN 3 THEN 'Bezahlt'
        ELSE 'Status ' || rk.status::TEXT
    END AS status_label,

    -- Betraege
    rk.net_amount,

    -- Flags
    rk.istdeleted,
    COALESCE(rk.correction_id, 0) AS correction_id,
    CASE
        WHEN COALESCE(rk.correction_id, 0) > 0 THEN 1
        ELSE 0
    END AS is_correction,

    -- Alter der Invoice (fuer Analysen)
    (CURRENT_DATE - rk.datum::DATE) AS days_old,
    CASE
        WHEN (CURRENT_DATE - rk.datum::DATE) <= 14 THEN '0-14 Tage'
        WHEN (CURRENT_DATE - rk.datum::DATE) <= 30 THEN '15-30 Tage'
        WHEN (CURRENT_DATE - rk.datum::DATE) <= 60 THEN '31-60 Tage'
        WHEN (CURRENT_DATE - rk.datum::DATE) <= 90 THEN '61-90 Tage'
        ELSE 'Ueber 90 Tage'
    END AS altersgruppe

FROM invoice_insurer rk;

COMMENT ON VIEW vw_dim_invoice_insurer IS
'Invoicekasse-Dimension mit Status-Bezeichnungen und Altersgruppen.
Status: 1=Neu, 2=Bestaetigt, 3=Bezahlt.';
