#!/bin/sh
set -e
TS=$(date "+%Y-%m-%d %H:%M:%S")
echo "[time-writer] inserting: $TS"
export PGPASSWORD="$DB_PASSWORD"
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "INSERT INTO time_logs (logged_at) VALUES ('$TS');"
echo "[time-writer] done"
