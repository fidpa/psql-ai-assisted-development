-- =====================================================
-- TABELLE: kpi_historie
-- Taegliche KPI-Snapshots fuer Trendanalysen
-- Version: 1.0 (PostgreSQL)
-- =====================================================
--
-- Speichert taegliche Snapshots aller KPIs fuer:
-- - Trend-Analysen in Power BI
-- - Historische Vergleiche
-- - Delta-Calculationen (Tag-zu-Tag)
-- - 7-Tage-Durchschnitte
--
-- Abhaengigkeiten: vw_kpi_dashboard_gesamt
-- =====================================================

-- Tabelle erstellen
CREATE TABLE IF NOT EXISTS kpi_historie (
    -- Primaerschluessel
    snapshot_date DATE NOT NULL PRIMARY KEY,

    -- E-Werte (Empfang)
    e1 INTEGER,
    e2 INTEGER,

    -- S-Werte (Scanning)
    s1 INTEGER,
    s2 INTEGER,
    s3 INTEGER,

    -- D-Werte (Datencapture)
    d0 INTEGER,
    d1 INTEGER,
    d2 INTEGER,
    d3 INTEGER,
    d4 INTEGER,

    -- C-Werte (Controlling)
    c1 NUMERIC(18,2),
    c2 INTEGER,

    -- Zusaetzliche Metriken
    estimated_gross_sum NUMERIC(18,2),
    working_days_to_month_end INTEGER,
    expiringe_vo_gesamt INTEGER,

    -- Audit
    erstellt_am TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aktualisiert_am TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- INDIZES
-- =====================================================

-- Absteigend fuer neueste zuerst
CREATE INDEX IF NOT EXISTS idx_kpi_historie_date_desc
    ON kpi_historie(snapshot_date DESC);

-- Jahr/Monat fuer Aggregationen
CREATE INDEX IF NOT EXISTS idx_kpi_historie_jahr_month
    ON kpi_historie(EXTRACT(YEAR FROM snapshot_date), EXTRACT(MONTH FROM snapshot_date));

-- =====================================================
-- KOMMENTAR
-- =====================================================

COMMENT ON TABLE kpi_historie IS
'Taegliche KPI-Snapshots fuer Power BI Trendanalysen.
Wird taeglich per fn_snapshot_kpi_historie() befuellt.
Primaerschluessel: snapshot_date (ein Eintrag pro Tag).';

-- =====================================================
-- SNAPSHOT-FUNKTION
-- =====================================================

CREATE OR REPLACE FUNCTION fn_snapshot_kpi_historie()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_date DATE := CURRENT_DATE;
    v_action TEXT;
BEGIN
    -- UPSERT: Insert oder Update bei Konflikt
    INSERT INTO kpi_historie (
        snapshot_date,
        e1, e2,
        s1, s2, s3,
        d0, d1, d2, d3, d4,
        c1, c2,
        estimated_gross_sum,
        working_days_to_month_end,
        expiringe_vo_gesamt,
        erstellt_am,
        aktualisiert_am
    )
    SELECT
        CURRENT_DATE,
        e1_last_working_day,
        e2_letzte_3_working_days,
        s1_naechste_3_tage,
        s2_naechste_6_tage,
        s3_gesamt,
        d0_heute,
        d1_naechste_3_tage,
        d2_naechste_6_tage,
        d3_gesamt,
        d4_expiringe_vo_ohne_kr,
        c1_nettosumme_unbestaetigte_kr,
        c2_count_unbestaetigte_kr,
        estimated_gross_sum,
        working_days_to_month_end,
        expiringe_vo_gesamt,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM vw_kpi_dashboard_gesamt
    ON CONFLICT (snapshot_date) DO UPDATE SET
        e1 = EXCLUDED.e1,
        e2 = EXCLUDED.e2,
        s1 = EXCLUDED.s1,
        s2 = EXCLUDED.s2,
        s3 = EXCLUDED.s3,
        d0 = EXCLUDED.d0,
        d1 = EXCLUDED.d1,
        d2 = EXCLUDED.d2,
        d3 = EXCLUDED.d3,
        d4 = EXCLUDED.d4,
        c1 = EXCLUDED.c1,
        c2 = EXCLUDED.c2,
        estimated_gross_sum = EXCLUDED.estimated_gross_sum,
        working_days_to_month_end = EXCLUDED.working_days_to_month_end,
        expiringe_vo_gesamt = EXCLUDED.expiringe_vo_gesamt,
        aktualisiert_am = CURRENT_TIMESTAMP;

    -- Pruefen ob Insert oder Update
    IF NOT FOUND THEN
        v_action := 'Kein Datensatz erstellt (Dashboard leer?)';
    ELSIF EXISTS (SELECT 1 FROM kpi_historie WHERE snapshot_date = v_date AND erstellt_am = aktualisiert_am) THEN
        v_action := 'INSERT';
    ELSE
        v_action := 'UPDATE';
    END IF;

    RETURN format('KPI-Snapshot %s: %s fuer %s', v_action, v_date, CURRENT_TIMESTAMP::TEXT);
END;
$$;

COMMENT ON FUNCTION fn_snapshot_kpi_historie() IS
'Erstellt oder aktualisiert den KPI-Snapshot fuer heute.
Aufruf: SELECT fn_snapshot_kpi_historie();
Verwendet UPSERT (INSERT ... ON CONFLICT DO UPDATE).';

-- =====================================================
-- CLEANUP-FUNKTION (optional)
-- =====================================================

CREATE OR REPLACE FUNCTION fn_cleanup_kpi_historie(monate_behalten INTEGER DEFAULT 12)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted INTEGER;
    v_cutoff DATE;
BEGIN
    v_cutoff := CURRENT_DATE - (monate_behalten || ' months')::INTERVAL;

    DELETE FROM kpi_historie
    WHERE snapshot_date < v_cutoff;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN format('Deleted: %s Eintraege aelter als %s', v_deleted, v_cutoff);
END;
$$;

COMMENT ON FUNCTION fn_cleanup_kpi_historie(INTEGER) IS
'Loescht alte Historie-Eintraege.
Parameter: Anzahl Monate die behalten werden (Standard: 12).
Aufruf: SELECT fn_cleanup_kpi_historie(12);';

-- =====================================================
-- SCHEDULING (pg_cron Extension, falls installiert)
-- =====================================================
-- -- Taeglich um 06:00 Uhr Snapshot erstellen:
-- SELECT cron.schedule('kpi_snapshot', '0 6 * * *',
--     'SELECT fn_snapshot_kpi_historie()');
--
-- -- Monatlich am 1. um 03:00 Uhr Cleanup (12 Monate behalten):
-- SELECT cron.schedule('kpi_cleanup', '0 3 1 * *',
--     'SELECT fn_cleanup_kpi_historie(12)');
--
-- -- Jobs anzeigen:
-- SELECT * FROM cron.job;
-- =====================================================

-- =====================================================
-- INITIALISIERUNG: Historische Daten nachtraeglich fuellen
-- =====================================================
-- Falls historische Daten aus SQL Server migriert werden:
--
-- INSERT INTO kpi_historie (snapshot_date, e1, e2, s1, s2, s3, d0, d1, d2, d3, d4, c1, c2, estimated_gross_sum, working_days_to_month_end, expiringe_vo_gesamt)
-- SELECT
--     snapshot_date,
--     e1, e2, s1, s2, s3, d0, d1, d2, d3, d4,
--     c1, c2, estimated_gross_sum,
--     working_days_to_month_end, expiringe_vo_gesamt
-- FROM sqlserver_kpi_historie_import;
-- =====================================================

-- =====================================================
-- VALIDIERUNG
-- =====================================================
--
-- -- Anzahl Eintraege:
-- SELECT COUNT(*), MIN(snapshot_date), MAX(snapshot_date)
-- FROM kpi_historie;
--
-- -- Letzte 7 Tage:
-- SELECT snapshot_date, e1, s3, d3, c1
-- FROM kpi_historie
-- ORDER BY snapshot_date DESC
-- LIMIT 7;
--
-- -- Luecken finden:
-- SELECT
--     snapshot_date,
--     snapshot_date - LAG(snapshot_date) OVER (ORDER BY snapshot_date) AS tage_seit_letztem
-- FROM kpi_historie
-- WHERE snapshot_date - LAG(snapshot_date) OVER (ORDER BY snapshot_date) > 1;
-- =====================================================
