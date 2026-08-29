-- =====================================================
-- KPI: Dashboard Gesamt
-- Zentrale View fuer Power BI Dashboard
-- Kombiniert alle KPI-Werte in einer Zeile
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_KPI_Dashboard_Gesamt (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - CAST(GETDATE() AS DATE) -> CURRENT_DATE
-- - DATENAME(WEEKDAY, d) -> CASE EXTRACT(ISODOW FROM d)...
-- - CONVERT(VARCHAR(10), d, 104) -> TO_CHAR(d, 'DD.MM.YYYY')
-- - GETDATE() -> CURRENT_TIMESTAMP
-- - ISNULL -> COALESCE
-- - TOP 1 -> LIMIT 1
--
-- Abhaengigkeiten: Alle KPI-Views (E, S, D, V, C)
-- =====================================================

CREATE OR REPLACE VIEW vw_kpi_dashboard_gesamt AS
WITH e_werte AS (
    SELECT
        e1_vorheriger_tag AS e1,
        e2_letzte_3_tage AS e2
    FROM vw_kpi_order_intake_kpis
    WHERE e1_vorheriger_tag IS NOT NULL
    ORDER BY datum DESC
    LIMIT 1
),
s_werte AS (
    SELECT * FROM vw_kpi_scanning_aggregated
),
d_werte AS (
    SELECT * FROM vw_kpi_capture_aggregated
),
v_werte AS (
    SELECT * FROM vw_kpi_expiry
),
c_werte AS (
    SELECT
        c1_nettosumme_unbestaetigte_kr AS c1,
        c2_count_unbestaetigte_kr AS c2
    FROM vw_kpi_controlling
)
SELECT
    -- Metadaten
    CURRENT_DATE AS datum,
    CASE EXTRACT(ISODOW FROM CURRENT_DATE)
        WHEN 1 THEN 'Montag'
        WHEN 2 THEN 'Dienstag'
        WHEN 3 THEN 'Mittwoch'
        WHEN 4 THEN 'Donnerstag'
        WHEN 5 THEN 'Freitag'
        WHEN 6 THEN 'Samstag'
        WHEN 7 THEN 'Sonntag'
    END AS wochentag,
    TO_CHAR(CURRENT_DATE, 'DD.MM.YYYY') AS date_formatiert,

    -- E-Werte (Empfang)
    COALESCE(e.e1, 0) AS e1_last_working_day,
    COALESCE(e.e2, 0) AS e2_letzte_3_working_days,

    -- S-Werte (Scanning)
    COALESCE(s.s1_naechste_3_tage, 0) AS s1_naechste_3_tage,
    COALESCE(s.s2_naechste_6_tage, 0) AS s2_naechste_6_tage,
    COALESCE(s.s3_gesamt, 0) AS s3_gesamt,

    -- D-Werte (Datencapture)
    COALESCE(d.d0_heute, 0) AS d0_heute,
    COALESCE(d.d1_naechste_3_tage, 0) AS d1_naechste_3_tage,
    COALESCE(d.d2_naechste_6_tage, 0) AS d2_naechste_6_tage,
    COALESCE(d.d3_gesamt, 0) AS d3_gesamt,
    COALESCE(d.estimated_gross_sum, 0) AS estimated_gross_sum,

    -- V-Werte (Expiry)
    COALESCE(v.working_days_to_month_end, 0) AS working_days_to_month_end,
    COALESCE(v.expiringe_vo_gesamt, 0) AS expiringe_vo_gesamt,
    COALESCE(v.d4_expiringe_vo_ohne_kr, 0) AS d4_expiringe_vo_ohne_kr,

    -- C-Werte (Controlling)
    COALESCE(c.c1, 0) AS c1_nettosumme_unbestaetigte_kr,
    COALESCE(c.c2, 0) AS c2_count_unbestaetigte_kr,

    -- Zeitstempel
    CURRENT_TIMESTAMP AS last_update

FROM (SELECT 1 AS dummy) base
LEFT JOIN e_werte e ON TRUE
LEFT JOIN s_werte s ON TRUE
LEFT JOIN d_werte d ON TRUE
LEFT JOIN v_werte v ON TRUE
LEFT JOIN c_werte c ON TRUE;

COMMENT ON VIEW vw_kpi_dashboard_gesamt IS
'Zentrales KPI-Dashboard fuer Power BI.
Kombiniert alle KPIs in einer Zeile:
- kpi_a/kpi_b: OrderIntake (letzter/letzte 3 WorkingDays)
- S1/S2/S3: Scanning-Backlog (3/6 Tage/Gesamt)
- D0-D4: Datencapture (Heute/3/6 Tage/Gesamt/Expiry ohne KR)
- C1/C2: Controlling (Nettosumme/Anzahl unbestaetigte KR)
Fuer DirectQuery optimiert - eine einzelne Zeile.';
