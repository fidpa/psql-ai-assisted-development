-- =====================================================
-- DIMENSION: ServiceType
-- Mapping der ServiceTypes
-- Version: 1.0 (PostgreSQL)
-- Migrated from: vw_Dim_ServiceType (SQL Server)
-- =====================================================
--
-- Konvertierungen:
-- - + (String-Concat) -> ||
-- - CAST(x AS VARCHAR(10)) -> x::TEXT
--
-- Abhaengigkeiten: Tabelle ServiceType
-- =====================================================

CREATE OR REPLACE VIEW vw_dim_service_type AS
SELECT
    lt.service_type_id,
    lt.nummer,
    -- Bezeichnung hart kodiert basierend auf Geschaeftslogik
    CASE lt.nummer
        WHEN 10 THEN 'Category10'
        WHEN 20 THEN 'Category20'
        WHEN 30 THEN 'Category30'
        WHEN 40 THEN 'Category40'
        ELSE 'ServiceType ' || lt.nummer::TEXT
    END AS label,

    -- Klassifizierung fuer Geschaeftslogik
    CASE
        WHEN lt.nummer IN (10, 20, 30, 40) THEN 'Automatic'
        ELSE 'Manual'
    END AS verarbeitungsart

FROM service_type lt;

COMMENT ON VIEW vw_dim_service_type IS
'ServiceType-Dimension mit Verarbeitungsart-Klassifizierung.
Automatische Verarbeitung: ServiceType IN (10, 20, 30, 40).';
