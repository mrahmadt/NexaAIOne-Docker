FROM ubuntu:22.04

LABEL maintainer="Ahmad AlTwaijiry ahmadt@gmail.com"

ARG PHP_VERSION=8.2
ARG NODE_MAJOR=20
ARG POSTGRES_VERSION=15
ARG SERVER_NAME=localhost
ARG COMPANY=Company
ARG APP_PORT=443
ARG USER_NAME=admin
ARG USER_EMAIL=admin@example.com
ARG USER_PASSWORD
ARG VERSION=33


WORKDIR /var/www/html

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC

## COMMON
RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python2 dnsutils librsvg2-bin fswatch \
    && curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor | tee /etc/apt/keyrings/nodesource.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y php${PHP_VERSION}-cli php${PHP_VERSION}-dev \
       php${PHP_VERSION}-pgsql php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-gd php${PHP_VERSION}-imagick \
       php${PHP_VERSION}-curl \
       php${PHP_VERSION}-imap php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring \
       php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-soap \
       php${PHP_VERSION}-intl php${PHP_VERSION}-readline \
       php${PHP_VERSION}-ldap \
       php${PHP_VERSION}-msgpack php${PHP_VERSION}-igbinary php${PHP_VERSION}-redis php${PHP_VERSION}-swoole \
       php${PHP_VERSION}-memcached php${PHP_VERSION}-pcov php${PHP_VERSION}-fpm \
    && curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && apt-get update \
    && apt-get install -y nodejs cron \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun \
    && apt-get install -y yarn \
    && apt-get install -y mysql-client \
    && apt-get install -y postgresql-client-$POSTGRES_VERSION \
    && apt-get -y update && apt-get -y install nginx libnginx-mod-http-headers-more-filter \
    && apt-get -y autoremove && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## NGINX
COPY nginx/default /etc/nginx/sites-available/default
COPY nginx/security.conf /etc/nginx/conf.d/security.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf

## NGINX Ports
## NGINX Hide nginx server header
## NGINX SSL self-signed certificate
RUN sed -i "s/listen 443/listen ${APP_PORT}/g" /etc/nginx/sites-available/default \
    && sed -i "s/listen \[::\]:443/listen \[::\]:${APP_PORT}/g" /etc/nginx/sites-available/default \
    && sed -i "s/server_name localhost;/server_name ${SERVER_NAME};/g" /etc/nginx/sites-available/default \
    && openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=${COMPANY}, Inc./CN=${SERVER_NAME}" -addext "subjectAltName=DNS:${SERVER_NAME}" -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt;

#    && sed -i 's/http {/http {\nserver_tokens off;\nmore_clear_headers Server;/g' /etc/nginx/nginx.conf \
# && if ! grep -q "more_clear_headers" /etc/nginx/nginx.conf; then \
    # sed -i 's/http {/http {\nserver_tokens off;\nmore_clear_headers Server;/g' /etc/nginx/nginx.conf; \
# fi \

COPY cron/schedule /etc/cron.d/
COPY start-container /usr/local/bin/start-container
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php/php.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-NexaAIOne.ini
COPY php/php.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-NexaAIOne.ini

RUN chmod 0644 /etc/cron.d/schedule \
    && chmod +x /usr/local/bin/start-container \
    && echo >> /etc/cron.d/schedule \
    && rm -rf /var/www/html/NexaAIOne \
    && git clone https://github.com/mrahmadt/NexaAIOne.git


COPY NexaAIOne/.env /var/www/html/NexaAIOne/.env
WORKDIR /var/www/html/NexaAIOne

RUN chown -R www-data:www-data /var/www/html/NexaAIOne \
    && su www-data -s /bin/bash -c "composer install --optimize-autoloader --no-dev" \
    && su www-data -s /bin/bash -c "php artisan key:generate" \
    && su www-data -s /bin/bash -c "php artisan config:cache" \
    && su www-data -s /bin/bash -c "php artisan event:cache" \
    && su www-data -s /bin/bash -c "php artisan route:cache" \
    && su www-data -s /bin/bash -c "php artisan view:cache" \
    && su www-data -s /bin/bash -c "php artisan storage:link" \
    && su www-data -s /bin/bash -c "php artisan optimize" \
    && su www-data -s /bin/bash -c "php artisan horizon:publish"


EXPOSE $APP_PORT

ENTRYPOINT ["start-container"]

