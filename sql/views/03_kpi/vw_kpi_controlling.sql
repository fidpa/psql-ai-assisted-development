-- =====================================================
-- KPI: C1 und C2 (Controlling)
-- Unbestaetigte InsurerInvoices
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_Controlling (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - EXISTS Subqueries bleiben identisch
-- - Spaltennamen lowercase
-- - 'Ueber 90 Tage' statt 'Über 90 Tage' (ASCII)
--
-- Abhaengigkeiten: vw_dim_invoice_insurer, vw_fact_order, zusatzposition
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_controlling AS
WITH unbestaetigte_kr AS (
    -- Basis: Unbestaetigte InsurerInvoices
    SELECT
        rk.invoice_insurer_id,
        rk.invoicesnummer,
        rk.invoice_date,
        rk.net_amount,
        rk.days_old,
        rk.altersgruppe
    FROM vw_dim_invoice_insurer rk
    WHERE rk.status = 1  -- Status "Neu/Unbestaetigt"
      AND rk.istdeleted = 0
      AND (rk.correction_id IS NULL OR rk.correction_id = 0)
),
invoiceen_mit_inhalt AS (
    -- Nur Invoiceen die Orders oder Zusatzpositionen haben
    SELECT DISTINCT
        uk.invoice_insurer_id,
        uk.invoicesnummer,
        uk.invoice_date,
        uk.net_amount,
        uk.days_old,
        uk.altersgruppe
    FROM unbestaetigte_kr uk
    WHERE EXISTS (SELECT 1 FROM vw_fact_order r
                  WHERE r.invoice_insurer_id = uk.invoice_insurer_id
                    AND r.is_gueltiges_order = 1)
       OR EXISTS (SELECT 1 FROM zusatzposition z
                  WHERE z.invoice_insurer_id = uk.invoice_insurer_id)
)
SELECT
    -- C1: Nettosumme
    SUM(net_amount) AS c1_nettosumme_unbestaetigte_kr,

    -- C2: Anzahl (NEU als eigener KPI!)
    COUNT(DISTINCT invoice_insurer_id) AS c2_count_unbestaetigte_kr,

    -- Bisherige Felder (fuer Kompatibilitaet)
    COUNT(DISTINCT invoice_insurer_id) AS count_unbestaetigte_kr,

    -- Nach Alter gruppiert
    SUM(CASE WHEN altersgruppe = '0-14 Tage' THEN net_amount ELSE 0 END) AS summe_0_14_tage,
    SUM(CASE WHEN altersgruppe = '15-30 Tage' THEN net_amount ELSE 0 END) AS summe_15_30_tage,
    SUM(CASE WHEN altersgruppe = '31-60 Tage' THEN net_amount ELSE 0 END) AS summe_31_60_tage,
    SUM(CASE WHEN altersgruppe = '61-90 Tage' THEN net_amount ELSE 0 END) AS summe_61_90_tage,
    SUM(CASE WHEN altersgruppe = 'Ueber 90 Tage' THEN net_amount ELSE 0 END) AS summe_ueber_90_tage,

    -- Anzahl nach Alter
    COUNT(CASE WHEN altersgruppe = '0-14 Tage' THEN 1 END) AS count_0_14_tage,
    COUNT(CASE WHEN altersgruppe = '15-30 Tage' THEN 1 END) AS count_15_30_tage,
    COUNT(CASE WHEN altersgruppe = '31-60 Tage' THEN 1 END) AS count_31_60_tage,
    COUNT(CASE WHEN altersgruppe = '61-90 Tage' THEN 1 END) AS count_61_90_tage,
    COUNT(CASE WHEN altersgruppe = 'Ueber 90 Tage' THEN 1 END) AS count_ueber_90_tage,

    -- Durchschnitte
    AVG(net_amount) AS durchschnitt_pro_invoice,
    AVG(days_old) AS durchschnittliches_alter,
    MIN(invoice_date) AS aelteste_invoice,
    MAX(invoice_date) AS neueste_invoice

FROM invoiceen_mit_inhalt;

COMMENT ON VIEW vw_kpi_controlling IS
'C-Werte (Controlling) KPIs.
C1 = Nettosumme aller unbestaetigten InsurerInvoices.
C2 = Anzahl unbestaetigter InsurerInvoices.
Nur Invoiceen mit Orders oder Zusatzpositionen.
Nach Altersgruppen aufgeschluesselt fuer Drill-Down.';
