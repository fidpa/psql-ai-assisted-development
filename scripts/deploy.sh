#!/bin/bash
# =====================================================
# PostgreSQL Deployment Script (Bash)
# OrderProcessing Data Warehouse
# =====================================================
#
# Applies scripts/deploy.sql to the target database.
#
# Usage:
#   ./deploy.sh [database] [host] [port] [user]
#
# Examples:
#   ./deploy.sh order_processing
#   ./deploy.sh order_processing localhost 5432 postgres
#
# The SQL file is resolved relative to this script, so the script can be
# started from any working directory (e.g. `bash scripts/deploy.sh` from the
# repository root).
#
# =====================================================

set -e  # Exit on error

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DEPLOY_SQL="${SCRIPT_DIR}/deploy.sql"

# Parameters with defaults
DB=${1:-order_processing}
HOST=${2:-localhost}
PORT=${3:-5432}
DB_USER=${4:-postgres}

if [[ ! -f "$DEPLOY_SQL" ]]; then
    echo "ERROR: SQL file not found: $DEPLOY_SQL" >&2
    exit 1
fi

echo ""
echo "========================================="
echo "PostgreSQL Deployment - OrderProcessing"
echo "========================================="
echo ""
echo "Connection details:"
echo "  Database:  $DB"
echo "  Host:      $HOST"
echo "  Port:      $PORT"
echo "  User:      $DB_USER"
echo "  SQL file:  $DEPLOY_SQL"
echo ""
read -r -p "Continue? (y/n) " -n 1 REPLY
echo
# [JjYy] on purpose: the prompt used to be German ("Fortfahren? (j/n)"), and
# an operator with that habit should not have a deployment cancelled on them.
if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Starting deployment..."
echo ""

psql -h "$HOST" -p "$PORT" -U "$DB_USER" -d "$DB" -f "$DEPLOY_SQL"

echo ""
echo "========================================="
echo "Deployment finished."
echo "========================================="
echo ""
