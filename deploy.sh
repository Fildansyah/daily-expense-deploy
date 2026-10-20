#!/bin/bash
set -e

# Deploy: pull repo & image terbaru dari GHCR, restart, migrasi
# (build image dilakukan GitHub Actions, VPS tidak perlu build)
cd "$(dirname "$0")"

echo "==> Pull repo"
git pull
git -C daily-expense-backend pull
git -C daily-expense-frontend pull

echo "==> Pull image dari GHCR & restart containers"
docker compose pull
docker compose up -d

echo "==> Jalankan migrasi (make migrate-up)"
(cd daily-expense-backend && make migrate-up)

echo "==> Status"
docker compose ps
