-- =====================================================
-- vw_dim_working_days: WorkingDays-Dimension mit deutschen Holidays
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Dim_WorkingDays (SQL Server)
-- =====================================================
--
-- KRITISCHE KONVERTIERUNGEN:
-- 1. Numbers-Tabelle -> GENERATE_SERIES (PostgreSQL-nativ)
-- 2. @@DATEFIRST + DATEPART(WEEKDAY) -> EXTRACT(ISODOW FROM date)
--    - SQL Server: Mo=2, Di=3, Mi=4, Do=5, Fr=6, Sa=7, So=1 (mit DATEFIRST=7)
--    - PostgreSQL ISODOW: Mo=1, Di=2, Mi=3, Do=4, Fr=5, Sa=6, So=7 (ISO-Standard)
-- 3. DATENAME(WEEKDAY) -> CASE-Statement fuer deutsche Namen
-- 4. DATEADD(DAY, n, date) -> date + n
-- 5. DATEFROMPARTS(y,m,d) -> MAKE_DATE(y,m,d)
-- 6. GETDATE() -> CURRENT_DATE
-- 7. FORMAT(..., 'yyyyMMdd') -> TO_CHAR(..., 'YYYYMMDD')
-- 8. EOMONTH(date) -> (DATE_TRUNC('month', date) + INTERVAL '1 month - 1 day')::DATE
--
-- Abhaengigkeit: fn_easter_sunday (muss zuerst erstellt werden)
-- =====================================================

CREATE OR REPLACE VIEW vw_dim_working_days AS
WITH
-- Datums-Bereich: 5 Jahre zurueck bis 5 Jahre voraus (~3650 Tage)
date_range AS (
    SELECT (DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '5 years')::DATE + n AS datum
    FROM GENERATE_SERIES(0, 3650) AS n
    WHERE (DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '5 years')::DATE + n
          <= (DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '6 years - 1 day')::DATE
),

-- Alle relevanten Jahre extrahieren
jahre AS (
    SELECT DISTINCT EXTRACT(YEAR FROM datum)::INTEGER AS jahr
    FROM date_range
),

-- Bewegliche Holidays (basierend auf EasterSunday)
movable_holidays AS (
    SELECT
        j.jahr,
        fn_easter_sunday(j.jahr) AS easter_sunday,
        fn_easter_sunday(j.jahr) - 2 AS karfreitag,           -- 2 Tage vor Ostern
        fn_easter_sunday(j.jahr) + 1 AS ostermontag,          -- 1 Tag nach Ostern
        fn_easter_sunday(j.jahr) + 39 AS christi_himmelfahrt, -- 39 Tage nach Ostern
        fn_easter_sunday(j.jahr) + 50 AS pfingstmontag        -- 50 Tage nach Ostern
    FROM jahre j
),

-- Alle Holidays zusammenfassen
alle_holidays AS (
    -- Fixe Holidays
    SELECT MAKE_DATE(j.jahr, 1, 1) AS datum, 'Neujahr' AS holiday
    FROM jahre j
    UNION ALL
    SELECT MAKE_DATE(j.jahr, 5, 1), 'Tag der Arbeit'
    FROM jahre j
    UNION ALL
    SELECT MAKE_DATE(j.jahr, 10, 3), 'Tag der Deutschen Einheit'
    FROM jahre j
    UNION ALL
    SELECT MAKE_DATE(j.jahr, 10, 31), 'Reformationstag'
    FROM jahre j
    UNION ALL
    SELECT MAKE_DATE(j.jahr, 12, 25), '1. Weihnachtstag'
    FROM jahre j
    UNION ALL
    SELECT MAKE_DATE(j.jahr, 12, 26), '2. Weihnachtstag'
    FROM jahre j

    -- Bewegliche Holidays
    UNION ALL
    SELECT karfreitag, 'Karfreitag' FROM movable_holidays
    UNION ALL
    SELECT ostermontag, 'Ostermontag' FROM movable_holidays
    UNION ALL
    SELECT christi_himmelfahrt, 'Christi Himmelfahrt' FROM movable_holidays
    UNION ALL
    SELECT pfingstmontag, 'Pfingstmontag' FROM movable_holidays
)

-- Hauptabfrage: Nur WorkingDays (kein Wochenende, kein Holiday)
SELECT
    d.datum,
    TO_CHAR(d.datum, 'YYYYMMDD')::INTEGER AS date_key,
    EXTRACT(YEAR FROM d.datum)::INTEGER AS jahr,
    EXTRACT(MONTH FROM d.datum)::INTEGER AS monat,
    EXTRACT(DAY FROM d.datum)::INTEGER AS tag,
    EXTRACT(QUARTER FROM d.datum)::INTEGER AS quartal,
    EXTRACT(WEEK FROM d.datum)::INTEGER AS kalenderwoche,

    -- Wochentag (deutsch)
    CASE EXTRACT(ISODOW FROM d.datum)
        WHEN 10 THEN 'Montag'
        WHEN 2 THEN 'Dienstag'
        WHEN 3 THEN 'Mittwoch'
        WHEN 4 THEN 'Donnerstag'
        WHEN 20 THEN 'Freitag'
        WHEN 6 THEN 'Samstag'
        WHEN 7 THEN 'Sonntag'
    END AS wochentag,

    -- Wochentag-Nummer (SQL Server Kompatibilitaet: Mo=2, Di=3, ..., So=1)
    -- ISODOW: Mo=1..So=7 -> Uminvoice: (ISODOW % 7) + 1 gibt Mo=2, Di=3, ..., Sa=7, So=1
    (EXTRACT(ISODOW FROM d.datum)::INTEGER % 7) + 1 AS wochentag_nr,

    -- WorkingDays-Nummerierung (absolute Nummer seit Start)
    DENSE_RANK() OVER (ORDER BY d.datum ASC) AS working_days_nr,

    -- Relative WorkingDays zu heute
    CASE
        WHEN d.datum < CURRENT_DATE THEN
            -DENSE_RANK() OVER (
                PARTITION BY CASE WHEN d.datum < CURRENT_DATE THEN 1 ELSE 0 END
                ORDER BY d.datum DESC
            )
        WHEN d.datum = CURRENT_DATE THEN 0
        ELSE
            DENSE_RANK() OVER (
                PARTITION BY CASE WHEN d.datum > CURRENT_DATE THEN 1 ELSE 0 END
                ORDER BY d.datum ASC
            )
    END AS working_days_relative_to_today,

    -- Status-Flags
    CASE WHEN d.datum < CURRENT_DATE THEN 1 ELSE 0 END AS is_vergangen,
    CASE WHEN d.datum = CURRENT_DATE THEN 1 ELSE 0 END AS is_heute,
    CASE WHEN d.datum > CURRENT_DATE THEN 1 ELSE 0 END AS is_zukunft,

    -- Monatsende
    (DATE_TRUNC('month', d.datum) + INTERVAL '1 month - 1 day')::DATE AS monatsende,
    CASE
        WHEN d.datum = (DATE_TRUNC('month', d.datum) + INTERVAL '1 month - 1 day')::DATE
        THEN 1 ELSE 0
    END AS is_monatsende,

    -- WorkingDays bis Monatsende (korrelierte Subquery)
    (SELECT COUNT(*)
     FROM date_range d2
     WHERE d2.datum > d.datum
       AND d2.datum <= (DATE_TRUNC('month', d.datum) + INTERVAL '1 month - 1 day')::DATE
       -- Kein Wochenende (ISODOW: Sa=6, So=7)
       AND EXTRACT(ISODOW FROM d2.datum) NOT IN (6, 7)
       -- Kein Holiday
       AND d2.datum NOT IN (SELECT datum FROM alle_holidays)
    ) AS working_days_to_month_end

FROM date_range d
WHERE
    -- Nur Werktage (Mo-Fr): ISODOW 1-5
    EXTRACT(ISODOW FROM d.datum) NOT IN (6, 7)
    -- Keine Holidays
    AND d.datum NOT IN (SELECT datum FROM alle_holidays);

COMMENT ON VIEW vw_dim_working_days IS
'WorkingDays-Dimension fuer deutsche WorkingDays.
Enthaelt alle Werktage (Mo-Fr) ohne deutsche Holidays.
Zeitraum: 5 Jahre zurueck bis 5 Jahre voraus.
Basis fuer: KPI-Calculationen, Expirylogik, Controlling.';

-- =====================================================
-- Validierungs-Queries (nach Installation ausfuehren):
-- =====================================================
--
-- WorkingDays-Anzahl pro Jahr pruefen:
-- SELECT jahr, COUNT(*) AS working_days
-- FROM vw_dim_working_days
-- WHERE jahr BETWEEN 2024 AND 2025
-- GROUP BY jahr
-- ORDER BY jahr;
-- Erwartet: ~250-252 WorkingDays pro Jahr
--
-- Ostermontag 2025 pruefen (sollte NICHT in View sein):
-- SELECT * FROM vw_dim_working_days WHERE datum = '2025-04-21';
-- Erwartet: Keine Zeilen (Ostermontag ist Holiday)
--
-- Wochentag-Nummern pruefen:
-- SELECT datum, wochentag, wochentag_nr
-- FROM vw_dim_working_days
-- WHERE datum BETWEEN '2025-01-06' AND '2025-01-10';
-- Erwartet: Mo=2, Di=3, Mi=4, Do=5, Fr=6
--
-- Relative WorkingDays pruefen:
-- SELECT datum, wochentag, working_days_relative_to_today
-- FROM vw_dim_working_days
-- WHERE working_days_relative_to_today BETWEEN -3 AND 3
-- ORDER BY datum;
