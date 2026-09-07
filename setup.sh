#!/usr/bin/env bash
set -euo pipefail

cd /var/www/html

echo "[setup] Ensuring storage directories exist..."
mkdir -p \
  storage/app/public \
  storage/framework/{cache,sessions,testing,views} \
  storage/logs \
  bootstrap/cache

chown -R www-data:www-data storage bootstrap/cache || true
chmod -R ug+rwx storage bootstrap/cache || true

if [ -z "${APP_KEY:-}" ] || [[ ! "${APP_KEY}" =~ ^base64: ]]; then
  echo "[setup] ERROR: APP_KEY is missing or invalid."
  echo "[setup] Generate one with: php -r \"echo 'base64:' . base64_encode(random_bytes(32)) . PHP_EOL;\""
  echo "[setup] Then set APP_KEY=base64:... in Dokploy (do NOT use a random short string)."
  exit 1
fi

echo "[setup] Clearing caches..."
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true
php artisan cache:clear || true

echo "[setup] Running migrations..."
php artisan migrate --force --no-interaction

echo "[setup] Linking public storage..."
php artisan storage:link --force || true

echo "[setup] Optimizing Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache || true
php artisan optimize

echo "[setup] Starting php-fpm..."
php-fpm -D

echo "[setup] Starting nginx..."
exec nginx -g "daemon off;"
