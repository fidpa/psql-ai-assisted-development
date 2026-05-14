-- =====================================================
-- KPI: Expiry (V) und D4
-- Nutzt die materialisierte Tabelle fuer Performance
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_Expiry (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - CAST(GETDATE() AS DATE) -> CURRENT_DATE
-- - EOMONTH(GETDATE()) -> (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE
-- - EOMONTH(GETDATE(), 1) -> (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '2 months - 1 day')::DATE
-- - CAST(x AS FLOAT) -> x::FLOAT
-- - [Date] -> datum
--
-- Abhaengigkeiten:
-- - vw_fact_expiry (oder fact_expiry_mat in Produktion)
-- - vw_dim_working_days
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_expiry AS
WITH monats_ende AS (
    SELECT
        (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE AS datum,
        (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '2 months - 1 day')::DATE AS naechster_monatsende
),
working_days_calc AS (
    SELECT COUNT(*) AS working_days_to_month_end
    FROM vw_dim_working_days
    WHERE datum > CURRENT_DATE
      AND datum <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE
),
basisdaten AS (
    SELECT
        v.*,
        (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE AS monatsende,
        CURRENT_DATE AS heute
    FROM vw_fact_expiry v
    WHERE v.exported = 0
      AND v.deleted = 0
      AND v.order_id_deleted = 0
      AND (v.correction_id = 0 OR v.correction_id IS NULL)
),
aggregationen AS (
    SELECT
        -- Expiring Orders (innerhalb aktueller Monat)
        COUNT(CASE
            WHEN v.expired_at <= v.monatsende
             AND v.expired_at > v.heute
            THEN 1
        END) AS expiringe_vo_gesamt,

        -- D4: Expiring ohne InsurerInvoice
        COUNT(CASE
            WHEN v.expired_at <= v.monatsende
             AND v.expired_at > v.heute
             AND v.ohne_insurer_invoice = 1
            THEN 1
        END) AS d4_expiringe_vo_ohne_kr,

        -- Zusaetzliche Metriken fuer Dashboard
        COUNT(CASE
            WHEN v.days_until_expiry BETWEEN 0 AND 20
            THEN 1
        END) AS kritisch_naechste_20_tage,

        COUNT(CASE
            WHEN v.days_until_expiry BETWEEN 21 AND 30
            THEN 1
        END) AS warnung_naechste_30_tage,

        -- Nach Status gruppiert
        COUNT(CASE
            WHEN v.expiry_status = 'Kritisch (<=20 Tage)'
             AND v.ohne_insurer_invoice = 1
            THEN 1
        END) AS kritisch_ohne_kr,

        -- Summen fuer Drill-Down
        SUM(CASE
            WHEN v.days_until_expiry < 0
            THEN 1 ELSE 0
        END) AS bereits_expired,

        -- Durchschnittliche Tage bis Expiry
        AVG(CASE
            WHEN v.days_until_expiry >= 0
            THEN v.days_until_expiry::FLOAT
            ELSE NULL
        END) AS durchschnitt_days_until_expiry

    FROM basisdaten v
)
SELECT
    -- Zeitrahmen
    CURRENT_DATE AS abfragedatum,
    m.datum AS monatsende,
    ab.working_days_to_month_end,

    -- Alle aggregierten KPIs
    ag.expiringe_vo_gesamt,
    ag.d4_expiringe_vo_ohne_kr,
    ag.kritisch_naechste_20_tage,
    ag.warnung_naechste_30_tage,
    ag.kritisch_ohne_kr,
    ag.bereits_expired,
    ag.durchschnitt_days_until_expiry

FROM monats_ende m
CROSS JOIN working_days_calc ab
CROSS JOIN aggregationen ag;

COMMENT ON VIEW vw_kpi_expiry IS
'V-Werte (Expiry) und D4 KPI.
D4 = Expiring Orders ohne InsurerInvoice bis Monatsende.
Expiry = 180 days after the reference event.
Kritisch = <= 20 Tage, Warnung = 21-30 Tage.';
