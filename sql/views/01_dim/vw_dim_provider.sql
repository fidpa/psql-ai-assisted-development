-- =====================================================
-- DIMENSION: Provider
-- Zentrale Dimension fuer alle Provider-bezogenen Analysen
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Dim_Provider_legacy (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - ISNULL(x, 0) -> COALESCE(x, 0)
-- - + (String-Concat) -> ||
-- - CAST(x AS VARCHAR(10)) -> x::TEXT
-- - GETDATE() -> CURRENT_TIMESTAMP
-- - EXISTS Subqueries bleiben identisch
--
-- Abhaengigkeiten: Tabellen Provider, ProviderGroupAssignment
-- =====================================================

CREATE OR REPLACE VIEW vw_dim_provider AS
SELECT
    -- Primaerschluessel
    b.provider_id,

    -- MasterData
    b.customer_no,
    b.company_name,
    b.contact_person,

    -- ServiceType
    b.service_type_id,
    CASE b.service_type_id
        WHEN 10 THEN 'Category10'
        WHEN 20 THEN 'Category20'
        WHEN 30 THEN 'Category30'
        WHEN 40 THEN 'Category40'
        ELSE 'Other (ID: ' || b.service_type_id::TEXT || ')'
    END AS service_type_label,

    -- Processing-Flags
    COALESCE(b.source_system_id, 0) AS source_system_id,
    CASE
        WHEN COALESCE(b.source_system_id, 0) > 0 THEN 1
        ELSE 0
    END AS has_source_system,
    b.do_not_capture_flag,

    -- Sentinel-Zugehoerigkeit (IDs 1 and 2)
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM provider_group_assignment bgz
            WHERE bgz.provider_id = b.provider_id
              AND bgz.provider_group_id IN (1, 2)
        ) THEN 1
        ELSE 0
    END AS is_sentinel,

    -- Abgeleitete Klassifizierung fuer Sorting-Logik
    CASE
        -- Spezielle ServiceTypes werden nicht manual sortiert
        WHEN b.service_type_id IN (10, 20, 30, 40) THEN 'Automatic'
        -- Sentinel wird nicht manual sortiert
        WHEN EXISTS (
            SELECT 1
            FROM provider_group_assignment bgz
            WHERE bgz.provider_id = b.provider_id
              AND bgz.provider_group_id IN (1, 2)
        ) THEN 'Sentinel'
        -- Mit SourceSystem wird nicht manual sortiert
        WHEN COALESCE(b.source_system_id, 0) > 0 THEN 'SourceSystem'
        -- Explizit nicht capture
        WHEN b.do_not_capture_flag = 1 THEN 'DoNotCapture'
        -- Rest wird manual sortiert
        ELSE 'Manual'
    END AS sorting_category,

    -- Hilfsspalten fuer Aggregationen
    CASE
        WHEN b.service_type_id IN (10, 20, 30, 40) THEN 0
        WHEN EXISTS (
            SELECT 1
            FROM provider_group_assignment bgz
            WHERE bgz.provider_id = b.provider_id
              AND bgz.provider_group_id IN (1, 2)
        ) THEN 0
        WHEN COALESCE(b.source_system_id, 0) > 0 THEN 0
        WHEN b.do_not_capture_flag = 1 THEN 0
        ELSE 1
    END AS must_be_manually_sorted,

    -- Audit-Informationen
    CURRENT_TIMESTAMP AS last_update

FROM provider b;

COMMENT ON VIEW vw_dim_provider IS
'Provider-Dimension mit Sentinel-Logik und Sorting-Kategorisierung.
Sentinel-Erkennung: ProviderGroupID IN (1, 2).
Automatische Verarbeitung: ServiceType IN (10, 20, 30, 40) oder SourceSystem.';

-- =====================================================
-- Validierungs-Queries (nach Installation ausfuehren):
-- =====================================================
-- Sentinel-Provider zaehlen:
-- SELECT sorting_category, COUNT(*) FROM vw_dim_provider GROUP BY sorting_category;
--
-- Provider mit SourceSystem:
-- SELECT COUNT(*) FROM vw_dim_provider WHERE has_source_system = 1;
