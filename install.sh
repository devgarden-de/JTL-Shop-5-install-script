#!/bin/bash
#
## Version 1.0.1 by Developers Garden (www.devgarden.de)
#
# JTL Shop 5 Installationsscript für Ubuntu/Debian
#
# Wir instalieren kein SSL (Certbot). Shop liegt hinter einem Revers-Proxy-Manager
# Beziehen SSL Zertifikate über den Revers-Proxy-Manager
# Epfehlung des Hauses -> https://github.com/fosrl/pangolin als Revers-Proxy-Manager
# Optional -> https://github.com/traefik/traefik oder -> https://github.com/NginxProxyManager/nginx-proxy-manager

set -e

# === Konfiguration ===
JTL_VERSION="v5-5-2"
JTL_ZIP_URL="https://build.jtl-shop.de/get/shop-$JTL_VERSION.zip"
JTL_INSTALL_DIR="/var/www/html/jtlshop"
TEMP_DIR="$PWD/jtlshop_download"
DB_NAME="jtlshop"
DB_USER="jtluser"
DB_PASS="sicherespasswort"
PHP_VERSION="8.3"
APACHE_CONF="/etc/apache2/sites-available/jtlshop.conf"
JTL_PHP_INI="/etc/php/${PHP_VERSION}/apache2/conf.d/99-jtl-shop.ini"

echo "=== System wird aktualisiert ==="
sudo apt update && sudo apt upgrade -y

echo "=== Erforderliche Pakete werden installiert ==="
sudo apt install -y apache2 mysql-server unzip curl \
php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-mysql \
php${PHP_VERSION}-gd php${PHP_VERSION}-xml php${PHP_VERSION}-curl \
php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-intl \
php${PHP_VERSION}-bcmath php${PHP_VERSION}-opcache php${PHP_VERSION}-apcu \
libapache2-mod-php${PHP_VERSION}

echo "=== Apache und MySQL werden gestartet ==="
sudo systemctl enable apache2
sudo systemctl enable mysql
sudo systemctl start apache2
sudo systemctl start mysql

echo "=== Eigene PHP-Konfiguration für JTL Shop wird erstellt ==="
sudo tee "$JTL_PHP_INI" > /dev/null <<EOL
; JTL Shop 5 PHP-Konfiguration

max_execution_time = 120
memory_limit = 128M
upload_max_filesize = 6M
post_max_size = 8M
allow_url_fopen = On

[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1

[apcu]
apc.enable_cli=1
EOL

echo "=== Apache-Module für Performance werden aktiviert ==="
sudo a2enmod rewrite deflate expires headers

echo "=== Apache wird neu gestartet ==="
sudo systemctl restart apache2

echo "=== Temporäres Verzeichnis wird erstellt ==="
mkdir -p "$TEMP_DIR"

echo "=== JTL Shop ZIP wird heruntergeladen ==="
curl -L "$JTL_ZIP_URL" -o "$TEMP_DIR/jtlshop.zip"

echo "=== ZIP-Datei wird entpackt ==="
mkdir -p "$JTL_INSTALL_DIR"
sudo unzip "$TEMP_DIR/jtlshop.zip" -d "$JTL_INSTALL_DIR"

echo "=== Cleanup ==="
sudo rm -rf "$TEMP_DIR"

echo "=== Dateiberechtigungen werden gesetzt ==="
sudo chown -R www-data:www-data "$JTL_INSTALL_DIR"
sudo find "$JTL_INSTALL_DIR" -type d -exec chmod 755 {} \;
sudo find "$JTL_INSTALL_DIR" -type f -exec chmod 644 {} \;

echo "=== MySQL-Datenbank wird eingerichtet ==="
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "=== Apache Konfiguration für JTL Shop wird erstellt ==="
sudo tee "$APACHE_CONF" > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $JTL_INSTALL_DIR

    <Directory $JTL_INSTALL_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/jtlshop_error.log
    CustomLog \${APACHE_LOG_DIR}/jtlshop_access.log combined
</VirtualHost>
EOL

echo "=== Apache-Konfiguration wird aktiviert ==="
sudo a2ensite jtlshop.conf
sudo systemctl reload apache2

echo "=== Installation abgeschlossen ==="
echo ">> Öffne im Browser: http://<deine-server-ip>/ zur JTL Shop Einrichtung"
