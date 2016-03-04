# Copy from the Wordpress Dockerfile
# updateted sections are: 
# "Processwire Dowload Part"

FROM php:5.6-apache

RUN a2enmod rewrite expires

# install the PHP extensions we need
RUN apt-get update && apt-get install -y libpng12-dev libjpeg-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd mysqli opcache

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

VOLUME /var/www/html


# Processwire Download Part
ENV PROCESSWIRE_VERSION 2.7.2
ENV PROCESSWIRE_STACKE master
ENV PROCESSWIRE_SHA1 bfde25a27432509dd060ff39a4e5aa8a71666fac

# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN curl -o processwire.zip -SL https://github.com/ryancramerdesign/ProcessWire/archive/${PROCESSWIRE_STACKE}.zip \
	&& echo "$PROCESSWIRE_SHA1 *processwire.zip" | sha1sum -c - \
	&& unzip processwire.zip /usr/src/ \
	&& rm processwire.zip \
	&& chown -R www-data:www-data /usr/src/processwire

COPY docker-entrypoint.sh /entrypoint.sh

# grr, ENTRYPOINT resets CMD now
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
