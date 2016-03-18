# Copy from the Wordpress Dockerfile
# updateted sections are: 
# "Processwire Dowload Part"

FROM php:5.5-apache
MAINTAINER kreativmonkey <webmaster@calyrium.org>

RUN a2enmod rewrite expires

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
#RUN { \
#		echo 'opcache.memory_consumption=128'; \
#		echo 'opcache.interned_strings_buffer=8'; \
#		echo 'opcache.max_accelerated_files=4000'; \
#		echo 'opcache.revalidate_freq=60'; \
#		echo 'opcache.fast_shutdown=1'; \
#		echo 'opcache.enable_cli=1'; \
#	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

#Install the Extensions we need
RUN apt-get update && apt-get -y upgrade \
	&& apt-get install -y pwgen curl unzip php5-mysql php-apc php5-cli \
	 	php5-curl php5-gd php5-mcrypt php5-intl php5-imap php5-tidy php5-imagick \
		php5-memcache php5-xmlrpc php5-xsl php5-mysql \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /var/www

# Download Processwire, check and install
ENV PROCESSWIRE_STACKE master
ENV PROCESSWIRE_SHA1 bfde25a27432509dd060ff39a4e5aa8a71666fac
ENV WEB_PATH /var/www/html

VOLUME ${WEB_PATH}

RUN curl -o processwire.zip -SL https://github.com/ryancramerdesign/ProcessWire/archive/${PROCESSWIRE_STACKE}.zip \
	&& echo "$PROCESSWIRE_SHA1 *processwire.zip" | sha1sum -c - \
	&& unzip processwire.zip -d /usr/src/ \
	&& rm processwire.zip \
	&& mv /usr/src/ProcessWire-${PROCESSWIRE_STACKE} /usr/src/processwire \
	&& mv /usr/src/processwire/site-beginner /usr/src/processwire/site \
	&& rm -rf /usr/src/processwire/site-* \
	&& chown -R www-data:www-data /usr/src/processwire

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

#start php
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
