# Migrations-Skripte

Versionierte SQL-Migrations-Skripte für PostgreSQL.

## Migrations-Reihenfolge
1. `001_initial_schema.sql` - Schema und Extensions
2. `002_create_dimensions.sql` - Dimensions-Views
3. `003_create_facts.sql` - Fakten-Views
4. `004_create_kpis.sql` - KPI-Views
5. `005_create_powerbi_views.sql` - Power BI Views
6. `006_create_materialized_views.sql` - Materialized Views

## Ausführung
Skripte müssen in numerischer Reihenfolge ausgeführt werden.
