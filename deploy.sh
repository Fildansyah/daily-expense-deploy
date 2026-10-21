#!/bin/bash
set -e

# Deploy: pull repo & image terbaru dari GHCR, restart, migrasi
# (build image dilakukan GitHub Actions, VPS tidak perlu build)
cd "$(dirname "$0")"

# JWT_SECRET dikelola sebagai GitHub Actions secret dan dikirim ke script ini.
# Nilai lama di .env selalu dihapus lalu ditulis ulang agar rotasi secret aman.
if [ -n "${JWT_SECRET:-}" ]; then
	if ! printf '%s' "$JWT_SECRET" | grep -Eq '^[A-Za-z0-9+/=_-]{32,}$'; then
		echo "JWT_SECRET tidak valid: minimal 32 karakter, hanya huruf/angka/+/=_-" >&2
		exit 1
	fi

	tmp_env="$(mktemp)"
	if [ -f .env ]; then
		grep -v '^JWT_SECRET=' .env > "$tmp_env" || true
	fi
	printf 'JWT_SECRET=%s\n' "$JWT_SECRET" >> "$tmp_env"
	mv "$tmp_env" .env
	chmod 600 .env
	echo "==> JWT_SECRET disinkronkan dari GitHub Actions"
fi

echo "==> Pull repo"
git pull
git -C daily-expense-backend pull
git -C daily-expense-frontend pull

echo "==> Pull image dari GHCR & restart containers"
docker compose pull
docker compose up -d

echo "==> Jalankan migrasi (make migrate-up)"
# Migrasi jalan di host (port db dipublish ke 127.0.0.1:5432) dan memakai
# password dari .env root, bukan dari daily-expense-backend/.env yang bisa usang.
POSTGRES_PASSWORD_VALUE=""
if [ -f .env ]; then
	POSTGRES_PASSWORD_VALUE="$(grep -E '^POSTGRES_PASSWORD=' .env | tail -n 1 | cut -d= -f2-)"
fi
DB_URL="postgres://postgres:${POSTGRES_PASSWORD_VALUE:-postgres}@127.0.0.1:5432/daily-expense?sslmode=disable"
(cd daily-expense-backend && DB_URL="$DB_URL" make migrate-up)

echo "==> Status"
docker compose ps
