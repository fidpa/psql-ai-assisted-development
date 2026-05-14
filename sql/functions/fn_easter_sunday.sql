-- =====================================================
-- fn_easter_sunday: Berechnet EasterSunday nach Gauss-Algorithmus
-- Version: 1.0 (PostgreSQL)
-- Migrated from: dbo.fn_EasterSunday (SQL Server)
-- =====================================================
--
-- Konvertierungs-Notizen:
-- - DATEFROMPARTS(y,m,d) -> MAKE_DATE(y,m,d)
-- - @variable -> variable (keine @ Prefix in PostgreSQL)
-- - Ganzzahl-Division identisch (INTEGER / INTEGER = INTEGER)
-- - Modulo-Operator identisch (%)
--
-- Verwendung: SELECT fn_easter_sunday(2025);
-- Ergebnis:   2025-04-20 (EasterSunday 2025)
-- =====================================================

CREATE OR REPLACE FUNCTION fn_easter_sunday(jahr INTEGER)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE  -- Deterministisch: gleiches Jahr = gleiches Ergebnis
PARALLEL SAFE
AS $$
DECLARE
    a INTEGER := jahr % 19;
    b INTEGER := jahr / 100;
    c INTEGER := jahr % 100;
    d INTEGER := b / 4;
    e INTEGER := b % 4;
    f INTEGER := (b + 8) / 25;
    g INTEGER := (b - f + 1) / 3;
    h INTEGER := (19 * a + b - d - g + 15) % 30;
    i INTEGER := c / 4;
    k INTEGER := c % 4;
    l INTEGER := (32 + 2 * e + 2 * i - h - k) % 7;
    m INTEGER := (a + 11 * h + 22 * l) / 451;
    monat INTEGER := (h + l - 7 * m + 114) / 31;
    tag INTEGER := ((h + l - 7 * m + 114) % 31) + 1;
BEGIN
    RETURN MAKE_DATE(jahr, monat, tag);
END;
$$;

COMMENT ON FUNCTION fn_easter_sunday(INTEGER) IS
'Berechnet das Datum des EasterSundays fuer ein gegebenes Jahr nach dem Gauss-Algorithmus.
Basis fuer alle beweglichen deutschen Holidays (Karfreitag, Ostermontag, Himmelfahrt, Pfingsten).';

-- =====================================================
-- Validierungs-Queries (nach Installation ausfuehren):
-- =====================================================
-- SELECT fn_easter_sunday(2020);  -- Erwartet: 2020-04-12
-- SELECT fn_easter_sunday(2021);  -- Erwartet: 2021-04-04
-- SELECT fn_easter_sunday(2022);  -- Erwartet: 2022-04-17
-- SELECT fn_easter_sunday(2023);  -- Erwartet: 2023-04-09
-- SELECT fn_easter_sunday(2024);  -- Erwartet: 2024-03-31
-- SELECT fn_easter_sunday(2025);  -- Erwartet: 2025-04-20
