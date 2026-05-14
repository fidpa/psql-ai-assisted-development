-- =====================================================
-- PostgreSQL Validation Script
-- OrderProcessing Data Warehouse
-- =====================================================
--
-- Prueft nach Deployment:
-- - Alle Views existieren
-- - Funktionen funktionieren
-- - Basisdaten plausibel
--
-- Usage:
--   psql -d order_processing -f validate.sql
--
-- =====================================================

\set ON_ERROR_STOP off

\echo ''
\echo '========================================='
\echo 'PostgreSQL Deployment Validierung'
\echo '========================================='
\echo ''

-- =====================================================
-- 1. Funktionen pruefen
-- =====================================================
\echo '1. Funktionen validieren...'
\echo ''

\echo '   - fn_easter_sunday(2025):'
SELECT fn_easter_sunday(2025) AS easter_sunday_2025,
       CASE WHEN fn_easter_sunday(2025) = '2025-04-20'::DATE
            THEN 'OK' ELSE 'FEHLER' END AS status;

\echo '   - fn_working_days_between:'
SELECT fn_working_days_between('2025-01-01'::DATE, '2025-01-31'::DATE) AS working_days_januar_2025,
       CASE WHEN fn_working_days_between('2025-01-01'::DATE, '2025-01-31'::DATE) BETWEEN 20 AND 23
            THEN 'OK' ELSE 'FEHLER' END AS status;

-- =====================================================
-- 2. Views zaehlen
-- =====================================================
\echo ''
\echo '2. Views zaehlen...'
\echo ''

SELECT
    schemaname,
    COUNT(*) FILTER (WHERE viewname LIKE 'vw_dim_%') AS dim_views,
    COUNT(*) FILTER (WHERE viewname LIKE 'vw_fact_%') AS fact_views,
    COUNT(*) FILTER (WHERE viewname LIKE 'vw_kpi_%') AS kpi_views,
    COUNT(*) FILTER (WHERE viewname LIKE 'vw_powerbi_%') AS powerbi_views,
    COUNT(*) AS total_views
FROM pg_views
WHERE schemaname IN ('public', 'order_processing')
GROUP BY schemaname;

-- =====================================================
-- 3. WorkingDays pruefen
-- =====================================================
\echo ''
\echo '3. WorkingDays 2025 pruefen...'
\echo ''

SELECT
    COUNT(*) AS working_days_2025,
    CASE WHEN COUNT(*) BETWEEN 250 AND 252
         THEN 'OK' ELSE 'WARNUNG' END AS status
FROM vw_dim_working_days
WHERE jahr = 2025;

-- =====================================================
-- 4. Materialized View pruefen
-- =====================================================
\echo ''
\echo '4. Materialized View pruefen...'
\echo ''

SELECT
    COUNT(*) AS count_zeilen,
    CASE WHEN COUNT(*) > 0
         THEN 'OK (gefuellt)'
         ELSE 'WARNUNG (leer - fn_refresh_expiry_mat() ausfuehren)'
    END AS status
FROM fact_expiry_mat;

-- =====================================================
-- 5. KPI-Dashboard pruefen
-- =====================================================
\echo ''
\echo '5. KPI-Dashboard pruefen...'
\echo ''

SELECT
    datum,
    e1_last_working_day,
    e2_letzte_3_working_days,
    s3_gesamt,
    d3_gesamt,
    c1_nettosumme_unbestaetigte_kr,
    CASE WHEN datum = CURRENT_DATE
         THEN 'OK' ELSE 'WARNUNG (nicht heute)' END AS status
FROM vw_kpi_dashboard_gesamt;

-- =====================================================
-- 6. Historie-Tabelle pruefen
-- =====================================================
\echo ''
\echo '6. Historie-Tabelle pruefen...'
\echo ''

SELECT
    COUNT(*) AS count_snapshots,
    MIN(snapshot_date) AS aeltester_snapshot,
    MAX(snapshot_date) AS neuester_snapshot,
    CASE WHEN COUNT(*) > 0
         THEN 'OK'
         ELSE 'INFO (leer - fn_snapshot_kpi_historie() ausfuehren)'
    END AS status
FROM kpi_historie;

-- =====================================================
-- 7. PowerBI Views pruefen
-- =====================================================
\echo ''
\echo '7. PowerBI Views pruefen...'
\echo ''

\echo '   - vw_powerbi_dashboard_live:'
SELECT COUNT(*) AS zeilen FROM vw_powerbi_dashboard_live;

\echo '   - vw_powerbi_historie:'
SELECT COUNT(*) AS zeilen FROM vw_powerbi_historie;

\echo '   - vw_powerbi_provideranalyse:'
SELECT COUNT(*) AS zeilen FROM vw_powerbi_provideranalyse;

\echo '   - vw_powerbi_order_intake_detail:'
SELECT COUNT(*) AS zeilen FROM vw_powerbi_order_intake_detail;

-- =====================================================
-- Zusammenfassung
-- =====================================================
\echo ''
\echo '========================================='
\echo 'Validierung abgeschlossen!'
\echo '========================================='
\echo ''
\echo 'Falls Warnungen:'
\echo '  - Materialized View fuellen: SELECT fn_refresh_expiry_mat();'
\echo '  - KPI-Snapshot erstellen: SELECT fn_snapshot_kpi_historie();'
\echo ''
