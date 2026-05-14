#!/bin/bash
# =====================================================
# PostgreSQL Deployment Script (Bash)
# OrderProcessing Data Warehouse
# =====================================================
#
# Usage:
#   ./deploy.sh [database] [host] [port] [user]
#
# Examples:
#   ./deploy.sh order_processing
#   ./deploy.sh order_processing localhost 5432 postgres
#
# =====================================================

set -e  # Exit on error

# Parameter mit Defaults
DB=${1:-order_processing}
HOST=${2:-localhost}
PORT=${3:-5432}
USER=${4:-postgres}

echo ""
echo "========================================="
echo "PostgreSQL Deployment - OrderProcessing"
echo "========================================="
echo ""
echo "Verbindungsdetails:"
echo "  Datenbank: $DB"
echo "  Host:      $HOST"
echo "  Port:      $PORT"
echo "  User:      $USER"
echo ""
read -p "Fortfahren? (j/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    echo "Abgebrochen."
    exit 1
fi

# Deployment ausfuehren
echo ""
echo "Starte Deployment..."
echo ""

psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -f deploy.sql

echo ""
echo "========================================="
echo "Deployment abgeschlossen!"
echo "========================================="
echo ""
