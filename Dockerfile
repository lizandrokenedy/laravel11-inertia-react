FROM php:8.3-apache as base
WORKDIR /var/app

RUN apt-get update
RUN apt-get install -y \
    libzip-dev \
    libicu-dev \
    libbz2-dev \
    libpng-dev \
    libjpeg-dev \
    libmcrypt-dev \
    libreadline-dev \
    libfreetype6-dev

RUN docker-php-ext-install \
    zip \
    bz2 \
    intl \
    bcmath \
    opcache \
    calendar \
    pdo_mysql \
    mysqli

RUN docker-php-ext-configure gd --with-jpeg=/usr/include/
RUN docker-php-ext-install gd

# 2. set up document root for apache
COPY infra/apache/000-default.conf /etc/apache2/sites-available/000-default.conf

# 3. mod_rewrite for URL rewrite and mod_headers for .htaccess extra headers like Access-Control-Allow-Origin-
RUN a2enmod rewrite headers

FROM base AS build
WORKDIR /app/build
COPY . .

ENV NODE_VERSION=20.12.2
# RUN apt-get update
# RUN apt-get install -y \
#     git \
#     zip \
#     curl \
#     sudo \
#     unzip \
#     libzip-dev \
#     libicu-dev \
#     libbz2-dev \
#     libpng-dev \
#     libjpeg-dev \
#     libmcrypt-dev \
#     libreadline-dev \
#     libfreetype6-dev \
#     g++

COPY --from=composer /usr/bin/composer /usr/bin/composer
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version

RUN composer install --no-dev
RUN npm install && npm run build

FROM base AS final
WORKDIR /var/app
COPY --from=build /app/build .
RUN chown www-data:www-data -R storage/
EXPOSE 80
