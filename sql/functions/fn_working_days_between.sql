-- =====================================================
-- fn_working_days_between: Zaehlt WorkingDays zwischen zwei Daten
-- Version: 1.0 (PostgreSQL)
-- Migrated from: dbo.fn_WorkingDaysBetween (SQL Server)
-- =====================================================
--
-- Abhaengigkeit: vw_dim_working_days (muss zuerst erstellt werden)
--
-- Konvertierungs-Notizen:
-- - @Von, @Bis -> from_date, to_date
-- - [Date] -> datum (PostgreSQL: keine eckigen Klammern)
-- - Bereich: from_date < datum <= to_date (exklusiv/inklusiv)
--
-- Verwendung: SELECT fn_working_days_between('2025-01-01', '2025-01-31');
-- =====================================================

CREATE OR REPLACE FUNCTION fn_working_days_between(from_date DATE, to_date DATE)
RETURNS INTEGER
LANGUAGE sql
STABLE  -- Abhaengig von View-Daten, aber konsistent innerhalb Transaktion
PARALLEL SAFE
AS $$
    SELECT COUNT(*)::INTEGER
    FROM vw_dim_working_days
    WHERE datum > from_date
      AND datum <= to_date;
$$;

COMMENT ON FUNCTION fn_working_days_between(DATE, DATE) IS
'Zaehlt die Anzahl der WorkingDays zwischen zwei Daten.
Bereich: from_date (exklusiv) bis to_date (inklusiv).
Benoetigt: vw_dim_working_days View muss existieren.';

-- =====================================================
-- Validierungs-Queries (nach Installation ausfuehren):
-- =====================================================
-- Normale Woche (Mo-Fr):
-- SELECT fn_working_days_between('2025-01-06', '2025-01-10');  -- Mo bis Fr = 4 Tage
--
-- Ueber Wochenende:
-- SELECT fn_working_days_between('2025-01-10', '2025-01-13');  -- Fr bis Mo = 1 Tag
--
-- Mit Holiday (Neujahr):
-- SELECT fn_working_days_between('2024-12-31', '2025-01-02');  -- 0 oder 1 (je nach Wochentag)
