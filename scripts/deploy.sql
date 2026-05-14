-- =====================================================
-- PostgreSQL Deployment Script
-- OrderProcessing Data Warehouse
-- =====================================================
--
-- Idempotent: Kann mehrfach ausgefuehrt werden
-- Transaktional: BEGIN/COMMIT fuer atomares Deployment
-- 29 Dateien in korrekter Abhaengigkeitsreihenfolge
--
-- Usage:
--   psql -h localhost -p 5432 -d order_processing -f deploy.sql
--   oder: ./deploy.sh order_processing localhost 5432
--
-- =====================================================

\set ON_ERROR_STOP on

\echo ''
\echo '========================================='
\echo 'PostgreSQL Deployment - OrderProcessing'
\echo '========================================='
\echo ''

BEGIN;

-- =====================================================
-- Phase 1: Schema
-- =====================================================
\echo 'Phase 1: Schema erstellen...'
\ir ../sql/schemas/01_schema.sql

-- =====================================================
-- Phase 2: Funktionen
-- =====================================================
\echo 'Phase 2: Funktionen erstellen...'
\ir ../sql/functions/fn_easter_sunday.sql
\ir ../sql/functions/fn_working_days_between.sql

-- =====================================================
-- Phase 3: Dimension Views (5 Views)
-- =====================================================
\echo 'Phase 3: Dimension Views erstellen...'
\ir ../sql/views/01_dim/vw_dim_working_days.sql
\ir ../sql/views/01_dim/vw_dim_provider.sql
\ir ../sql/views/01_dim/vw_dim_service_type.sql
\ir ../sql/views/01_dim/vw_dim_customer.sql
\ir ../sql/views/01_dim/vw_dim_invoice_insurer.sql

-- =====================================================
-- Phase 4: Fact Views (4 Views)
-- =====================================================
\echo 'Phase 4: Fact Views erstellen...'
\ir ../sql/views/02_fact/vw_fact_order_intake.sql
\ir ../sql/views/02_fact/vw_fact_order.sql
\ir ../sql/views/02_fact/vw_fact_invoice_provider.sql
\ir ../sql/views/02_fact/vw_fact_expiry_calculation.sql

-- =====================================================
-- Phase 5: Materialized View
-- =====================================================
\echo 'Phase 5: Materialized View erstellen...'
\ir ../sql/tables/fact_expiry_mat.sql

-- =====================================================
-- Phase 6: Wrapper View
-- =====================================================
\echo 'Phase 6: Wrapper View erstellen...'
\ir ../sql/views/02_fact/vw_fact_expiry.sql

-- =====================================================
-- Phase 7: KPI Views (10 Views)
-- =====================================================
\echo 'Phase 7: KPI Views erstellen...'
\ir ../sql/views/03_kpi/vw_kpi_order_sorting.sql
\ir ../sql/views/03_kpi/vw_kpi_order_sorting_basis.sql
\ir ../sql/views/03_kpi/vw_kpi_capture_status_complete.sql
\ir ../sql/views/03_kpi/vw_kpi_order_intake_kpis.sql
\ir ../sql/views/03_kpi/vw_kpi_scanning_aggregated.sql
\ir ../sql/views/03_kpi/vw_kpi_capture_aggregated.sql
\ir ../sql/views/03_kpi/vw_kpi_expiry.sql
\ir ../sql/views/03_kpi/vw_kpi_expiry_detail.sql
\ir ../sql/views/03_kpi/vw_kpi_controlling.sql
\ir ../sql/views/03_kpi/vw_kpi_dashboard_gesamt.sql

-- =====================================================
-- Phase 8: Historie-Tabelle
-- =====================================================
\echo 'Phase 8: Historie-Tabelle erstellen...'
\ir ../sql/tables/kpi_historie.sql

-- =====================================================
-- Phase 9: PowerBI Views (4 Views)
-- =====================================================
\echo 'Phase 9: PowerBI Views erstellen...'
\ir ../sql/views/04_powerbi/vw_powerbi_dashboard_live.sql
\ir ../sql/views/04_powerbi/vw_powerbi_historie.sql
\ir ../sql/views/04_powerbi/vw_powerbi_provideranalyse.sql
\ir ../sql/views/04_powerbi/vw_powerbi_order_intake_detail.sql

COMMIT;

\echo ''
\echo '========================================='
\echo 'Deployment erfolgreich abgeschlossen!'
\echo '========================================='
\echo ''
\echo 'Naechste Schritte:'
\echo '  1. Validierung: psql -d order_processing -f validate.sql'
\echo '  2. Materialized View fuellen: SELECT fn_refresh_expiry_mat();'
\echo '  3. KPI-Snapshot: SELECT fn_snapshot_kpi_historie();'
\echo ''
