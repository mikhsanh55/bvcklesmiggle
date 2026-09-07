# syntax=docker/dockerfile:1
#
# Bvcklesmiggle — production image for Dokploy
# PHP 8.3-FPM + Nginx + Supervisor
# Node 20 used only at build time (Vite assets)

ARG PHP_VERSION=8.3
ARG NODE_VERSION=20

# -----------------------------------------------------------------------------
# Stage 1: Frontend assets (Vite)
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-bookworm-slim AS frontend

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY vite.config.js postcss.config.js tailwind.config.js ./
COPY resources ./resources
COPY public ./public

RUN npm run build

# -----------------------------------------------------------------------------
# Stage 2: PHP dependencies (Composer)
# -----------------------------------------------------------------------------
FROM php:${PHP_VERSION}-cli-bookworm AS vendor

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

# -----------------------------------------------------------------------------
# Stage 3: Runtime (Nginx + PHP-FPM + Supervisor)
# -----------------------------------------------------------------------------
FROM php:${PHP_VERSION}-fpm-bookworm AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        curl \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libonig-dev \
        libxml2-dev \
        unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        opcache \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /var/log/supervisor

WORKDIR /var/www/html

# Application source
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=frontend /app/public/build ./public/build
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Docker configs
COPY docker/nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY setup.sh /usr/local/bin/setup.sh

RUN composer dump-autoload --optimize --no-dev --no-interaction \
    && rm /usr/bin/composer \
    && chmod +x /usr/local/bin/setup.sh \
    && sed -i 's/\r$//' /usr/local/bin/setup.sh \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R ug+rwx /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -f http://127.0.0.1/up || exit 1

ENTRYPOINT ["/usr/local/bin/setup.sh"]
