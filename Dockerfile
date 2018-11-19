FROM php:7.1-fpm

LABEL maintainer="llemoullec@gmail.com"

ARG TIMEZONE
ARG USER_NAME
ARG USER_UID
ARG GROUP_NAME
ARG GROUP_UID
ARG DOCKER_NAT_IP

ENV ICU_RELEASE 63.1
ENV NODE_VERSION 8.12.0
ENV YARN_VERSION 1.9.4

RUN apt-get update && \
    apt-get install --yes --assume-yes \
    cron \
    g++ \
    gettext \
    libicu-dev \
    openssl \
    libc-client-dev \
    libkrb5-dev \
    libxml2-dev \
    libfreetype6-dev \
    libgd-dev \
    bzip2 \
    libbz2-dev \
    libtidy-dev \
    libcurl4-openssl-dev \
    libz-dev \
    libmemcached-dev \
    libxslt-dev \
    git \
    zip \
    vim \
    gpg \
    libmagickwand-dev \
    libmagickcore-dev

# Use the default php.ini development configuration
RUN mv $PHP_INI_DIR/php.ini-development $PHP_INI_DIR/php.ini


# php.ini overrided settings

# memory_limit set to -1, needed in dev mode for some heavy composer task, don't use this in production !
# TODO: Override this memory_limit in a custom php.ini used by php cli env only
RUN sed -i 's/^memory_limit = 128M/memory_limit = -1/g' $PHP_INI_DIR/php.ini

# PHP Configuration
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install bz2
RUN docker-php-ext-install calendar
RUN docker-php-ext-install dba
RUN docker-php-ext-install exif
RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr
RUN docker-php-ext-install gd
RUN docker-php-ext-install gettext
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-install imap
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install soap
RUN docker-php-ext-install tidy
RUN docker-php-ext-install xmlrpc
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install xsl
RUN docker-php-ext-install zip
RUN docker-php-ext-configure hash --with-mhash

# Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug
COPY dockerfiles/conf/xdebug.ini $PHP_INI_DIR/conf.d/
RUN echo "xdebug.remote_host=${DOCKER_NAT_IP}" >> $PHP_INI_DIR/conf.d/xdebug.ini

# Imagemagick
RUN yes '' | pecl install -f imagick
RUN docker-php-ext-enable imagick

# Opcache php accelerator
RUN docker-php-ext-configure opcache --enable-opcache && docker-php-ext-install opcache
COPY dockerfiles/conf/opcache.ini $PHP_INI_DIR/conf.d/

# Update ICU data bundled to the symfony 3.4 required version
RUN curl -o /tmp/icu.tar.gz -L http://download.icu-project.org/files/icu4c/$ICU_RELEASE/icu4c-$(echo $ICU_RELEASE | tr '.' '_')-src.tgz && tar -zxf /tmp/icu.tar.gz -C /tmp && cd /tmp/icu/source && ./configure --prefix=/usr/local && make && make install
RUN docker-php-ext-configure intl --with-icu-dir=/usr/local
RUN docker-php-ext-install intl

# Install composer for PHP dependencies
RUN cd /tmp && curl https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Set timezone
RUN rm /etc/localtime
RUN ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# create a matching user from the host
RUN groupadd --gid ${GROUP_UID} ${GROUP_NAME} \
  && useradd --uid ${USER_UID} --gid ${GROUP_NAME} --shell /bin/bash --create-home ${USER_NAME}


# Node (Taken from node:8-slim)

# gpg keys listed at https://github.com/nodejs/node#release-team

RUN buildDeps='xz-utils' \
    && ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
      amd64) ARCH='x64';; \
      ppc64el) ARCH='ppc64le';; \
      s390x) ARCH='s390x';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armv7l';; \
      i386) ARCH='x86';; \
      *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && set -x \
    && apt-get update && apt-get install -y ca-certificates curl wget $buildDeps --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && apt-get purge -y --auto-remove $buildDeps \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs

# yarn
RUN curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz


WORKDIR /usr/local/apache2/htdocs
CMD ["php-fpm"]
