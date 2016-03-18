#!/bin/bash
set -e

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
	if [ -n "$MYSQL_PORT_3306_TCP" ]; then
		if [ -z "$PROCESSWIRE_DB_HOST" ]; then
			PROCESSWIRE_DB_HOST='mysql'
		else
			echo >&2 'warning: both PROCESSWIRE_DB_HOST and MYSQL_PORT_3306_TCP found'
			echo >&2 "  Connecting to PROCESSWIRE_DB_HOST ($PROCESSWIRE_DB_HOST)"
			echo >&2 '  instead of the linked mysql container'
		fi
	fi

	if [ -z "$PROCESSWIRE_DB_HOST" ]; then
		echo >&2 'error: missing PROCESSWIRE_DB_HOST and MYSQL_PORT_3306_TCP environment variables'
		echo >&2 '  Did you forget to --link some_mysql_container:mysql or set an external db'
		echo >&2 '  with -e PROCESSWIRE_DB_HOST=hostname:port?'
		exit 1
	fi

	# if we're linked to MySQL and thus have credentials already, let's use them
	: ${PROCESSWIRE_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}
	if [ "$PROCESSWIRE_DB_USER" = 'root' ]; then
		: ${PROCESSWIRE_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
	fi
	: ${PROCESSWIRE_DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
	: ${PROCESSWIRE_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-PROCESSWIRE}}

	if [ -z "$PROCESSWIRE_DB_PASSWORD" ]; then
		echo >&2 'error: missing required PROCESSWIRE_DB_PASSWORD environment variable'
		echo >&2 '  Did you forget to -e PROCESSWIRE_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 '  (Also of interest might be PROCESSWIRE_DB_USER and PROCESSWIRE_DB_NAME.)'
		exit 1
	fi

	if ! [ -e index.php -a -e wire/config.php ]; then
		echo >&2 "PROCESSWIRE not found in $(pwd) - copying now..."
		if [ "$(ls -A)" ]; then
			echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
			( set -x; ls -A; sleep 10 )
		fi
		tar cf - --one-file-system -C /usr/src/PROCESSWIRE . | tar xf -
		echo >&2 "Complete! PROCESSWIRE has been successfully copied to $(pwd)"
		if [ ! -e .htaccess ]; then
			# NOTE: The "Indexes" option is disabled in the php:apache base image
			cat > .htaccess <<-'EOF'
				# BEGIN PROCESSWIRE
				<IfModule mod_rewrite.c>
				RewriteEngine On
				RewriteBase /
				RewriteRule ^index\.php$ - [L]
				RewriteCond %{REQUEST_FILENAME} !-f
				RewriteCond %{REQUEST_FILENAME} !-d
				RewriteRule . /index.php [L]
				</IfModule>
				# END PROCESSWIRE
			EOF
			chown www-data:www-data .htaccess
		fi
	fi

	echo "/**" | tee site/config.php
 	echo "* Installer: Database Configuration" | tee site/config.php
 	echo "* " | tee site/config.php
	echo "*/" | tee site/config.php
	echo "\$config->dbHost = '$PROCESSWIRE_DB_HOST';" | tee site/config.php
	echo "\$config->dbName = '$PROCESSWIRE_DB_NAME';" | tee site/config.php
	echo "\$config->dbUser = '$PROCESSWIRE_DB_USER';" | tee site/config.php
	echo "\$config->dbPass = '$PROCESSWIRE_DB_PASSWORD';" | tee site/config.php
	echo "\$config->dbPort = '3306';" | tee site/config.php

	# allow any of these "Authentication Unique Keys and Salts." to be specified via
	# environment variables with a "PROCESSWIRE_" prefix (ie, "PROCESSWIRE_AUTH_KEY")
	UNIQUES=(
		USERAUTHSALT
	)
	for unique in "${UNIQUES[@]}"; do
		eval unique_value=\$PROCESSWIRE_$unique
		if [ "$unique_value" ]; then
			echo "\$config->userAuthSalt = $unique_value" | tee site/config.php
		fi
	done


	if [ "$PROCESSWIRE_DEBUG" ]; then
		set_config 'WP_DEBUG' 1 boolean
	fi

	TERM=dumb php -- "$PROCESSWIRE_DB_HOST" "$PROCESSWIRE_DB_USER" "$PROCESSWIRE_DB_PASSWORD" "$PROCESSWIRE_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)
$stderr = fopen('php://stderr', 'w');
list($host, $port) = explode(':', $argv[1], 2);
$maxTries = 10;
do {
	$mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);
	if ($mysql->connect_error) {
		fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
		--$maxTries;
		if ($maxTries <= 0) {
			exit(1);
		}
		sleep(3);
	}
} while ($mysql->connect_error);
if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
	fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}
$mysql->close();
EOPHP
fi

exec "$@"
