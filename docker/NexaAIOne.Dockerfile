FROM ubuntu:22.04

LABEL maintainer="Ahmad AlTwaijiry ahmadt@gmail.com"

ARG PHP_VERSION=8.2
ARG NODE_VERSION=18
ARG POSTGRES_VERSION=15
ARG SERVER_NAME=localhost
ARG COMPANY=Company
ARG APP_PORT=443
ARG USER_NAME=admin
ARG USER_EMAIL=admin@example.com
ARG USER_PASSWORD

WORKDIR /var/www/html

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC


## COMMON
# USER 0
RUN apt-get update
RUN mkdir -p /etc/apt/keyrings
RUN apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python2 dnsutils librsvg2-bin fswatch 


## PHP $PHP_VERSION
RUN curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null
RUN cat /etc/apt/keyrings/ppa_ondrej_php.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/ppa_ondrej_php.list

RUN apt-get update

RUN apt-get install -y php${PHP_VERSION}-cli php${PHP_VERSION}-dev \
       php${PHP_VERSION}-pgsql php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-gd php${PHP_VERSION}-imagick \
       php${PHP_VERSION}-curl \
       php${PHP_VERSION}-imap php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring \
       php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-soap \
       php${PHP_VERSION}-intl php${PHP_VERSION}-readline \
       php${PHP_VERSION}-ldap \
       php${PHP_VERSION}-msgpack php${PHP_VERSION}-igbinary php${PHP_VERSION}-redis php${PHP_VERSION}-swoole \
       php${PHP_VERSION}-memcached php${PHP_VERSION}-pcov php${PHP_VERSION}-fpm

RUN curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg  --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" > /etc/apt/sources.list.d/nodesource.list

RUN apt-get update \
    && apt-get install -y nodejs cron \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update \
    && apt-get install -y yarn \
    && apt-get install -y mysql-client \
    && apt-get install -y postgresql-client-$POSTGRES_VERSION

## NGINX
RUN apt-get -y update && apt-get -y install nginx libnginx-mod-http-headers-more-filter
COPY nginx/default /etc/nginx/sites-available/default

## NGINX Hide nginx server header
RUN sed -i 's/http {/http {\nserver_tokens off;\nmore_clear_headers Server;/g' /etc/nginx/nginx.conf
RUN rm /var/www/html/index.nginx-debian.html

# RUN mkdir -p /var/www/html/NexaAIOne/public
# COPY php/phpinfo.php /var/www/html/NexaAIOne/public/phpinfo.php

RUN sed -i "s/server_name localhost;/server_name ${SERVER_NAME};/g" /etc/nginx/sites-available/default

## NGINX SSL self-signed certificate
RUN openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=${COMPANY}, Inc./CN=${SERVER_NAME}" -addext "subjectAltName=DNS:${SERVER_NAME}" -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt;

## NGINX Ports
RUN sed -i "s/listen 443/listen ${APP_PORT}/g" /etc/nginx/sites-available/default
RUN sed -i "s/listen \[::\]:443/listen \[::\]:${APP_PORT}/g" /etc/nginx/sites-available/default

## Cron
COPY cron/schedule /etc/cron.d/schedule
RUN chmod 0644 /etc/cron.d/schedule
RUN echo >> /etc/cron.d/schedule

## OS Setup
COPY start-container /usr/local/bin/start-container
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php/php.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-NexaAIOne.ini
COPY php/php.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-NexaAIOne.ini
RUN chmod +x /usr/local/bin/start-container

## Clean up
RUN apt-get -y autoremove && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



## NexaAIOne
RUN git clone https://github.com/mrahmadt/NexaAIOne.git
## https://github.com/mrahmadt/NexaAIOne/releases/latest/download/package.zip
## https://api.github.com/repos/mrahmadt/NexaAIOne/zipball
## https://api.github.com/repos/mrahmadt/NexaAIOne/tarball
## https://codeload.github.com/mrahmadt/NexaAIOne/legacy.tar.gz/master
## https://stackoverflow.com/questions/43654656/dockerfile-if-else-condition-with-external-arguments

WORKDIR /var/www/html/NexaAIOne
COPY NexaAIOne/.env /var/www/html/NexaAIOne/.env

RUN chown -R www-data:www-data /var/www/html/NexaAIOne

# USER www-data

## NexaAIOne composer update
# RUN composer install --optimize-autoloader --no-dev
RUN su www-data -s /bin/bash -c "composer install --optimize-autoloader --no-dev"

## NexaAIOne Run laravel commands
RUN su www-data -s /bin/bash -c "php artisan key:generate"
RUN su www-data -s /bin/bash -c "php artisan config:cache"
RUN su www-data -s /bin/bash -c "php artisan event:cache"
RUN su www-data -s /bin/bash -c "php artisan route:cache"
RUN su www-data -s /bin/bash -c "php artisan view:cache"
RUN su www-data -s /bin/bash -c "php artisan storage:link"
RUN su www-data -s /bin/bash -c "php artisan optimize"
RUN su www-data -s /bin/bash -c "php artisan horizon:publish"

# RUN php artisan migrate --seed --force

## NexaAIOne add user to admin
# RUN php artisan make:filament-user --name "${USER_NAME}" --email "${USER_EMAIL}" --password "${USER_PASSWORD}" --no-interaction



EXPOSE $APP_PORT

ENTRYPOINT ["start-container"]

