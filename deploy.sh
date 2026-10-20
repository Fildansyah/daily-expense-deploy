#!/bin/bash
set -e

# Deploy: pull semua repo, rebuild container, jalankan migrasi
cd "$(dirname "$0")"

echo "==> Pull repo"
git pull
git -C daily-expense-backend pull
git -C daily-expense-frontend pull

echo "==> Build & restart containers"
docker compose up --build -d

echo "==> Jalankan migrasi (make migrate-up)"
(cd daily-expense-backend && make migrate-up)

echo "==> Status"
docker compose ps
