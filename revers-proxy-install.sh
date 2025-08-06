#!/bin/bash
#
## Version 1.0.3 by Developers Garden (www.devgarden.de)
#
# JTL Shop 5 Installationsscript für Ubuntu/Debian hinter einem Revers-Proxy-Manager
#
# Wir erstellen eigene SSL Zertifikate (Self Signed) für ein sauberen Betrieb des Shops.
# Beziehen SSL Zertifikate (Certbot) über den Revers-Proxy-Manager die von aussen sichtbar sind.
# INFO: Ist ein Reverse Proxy im Einsatz, so kann der Certbot nicht auf "example.com/.well-known/" zugreifen, weild der Pangolin Revers-Proxy-Manager das blockiert.
# 
# Stoppe Script bei Fehler
set -e

# === Konfiguration ===

# Domain, Server & email
DOMAIN="example.com"
SERVER_ADMIN_MAIL="admin@$DOMAIN"
SET_TIMEZONE="Europe/Berlin"

#EMAIL="webmaster@example.com"
EMAIL=$SERVER_ADMIN_MAIL

# MySQL Datenbank
DB_NAME="jtlshop"
DB_USER="jtluser"
DB_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

## JTL Version []
JTL_VERSION="v5-5-2"
## JTL Shop
JTL_ZIP_URL="https://build.jtl-shop.de/get/shop-$JTL_VERSION.zip"
# JTL Systemckeck 
TEST_SCRIPT="https://build.jtl-shop.de/get/shop5-systemcheck-5-0-0.zip"

# PHP
PHP_VERSION="8.2"
APACHE_CONF="/etc/apache2/sites-available/jtlshop.conf"
APACHE_CONF_SSL="/etc/apache2/sites-available/jtlshop-ssl.conf"
JTL_PHP_INI="/etc/php/${PHP_VERSION}/apache2/conf.d/99-jtl-shop-$JTL_VERSION.ini"

# Webroot
JTL_INSTALL_DIR="/var/www/html/jtlshop-$JTL_VERSION"

# UFW Firewall
USE_UFW_FIREWALL="false"    # UFW Firewall installieren und Aktivieren
UFW_OPEN_SSH="true"         # Erlaube SSH, damit du nicht ausgesperrt wirst!
UFW_OPEN_APACHE="true"      # Öffnet Ports 80 & 443 über die Apache2 Gruppe

# Scripthelfer
TEMP_DIR="$PWD/jtlshop_download"

# Selbst seginiertes Zertifkat
DAYS=36500
KEYFILE="${DOMAIN}.key"
CRTFILE="${DOMAIN}.crt"

# === Konfiguration ENDE ===

echo "=== Schreibe Log Datei ==="
exec > >(tee -a $PWD/JTL_install_logfile.log) 2>&1

echo "=== Server timezones ==="
timedatectl set-timezone $SET_TIMEZONE
timedatectl

echo "=== System wird aktualisiert ==="
sudo apt update && sudo apt upgrade -y

echo "=== Erforderliche Pakete werden installiert ==="
sudo apt install -y apache2 mariadb-server mariadb-client unzip curl \
php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-mysql \
php${PHP_VERSION}-gd php${PHP_VERSION}-xml php${PHP_VERSION}-curl \
php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-soap \
php${PHP_VERSION}-bcmath php${PHP_VERSION}-opcache php${PHP_VERSION}-apcu php${PHP_VERSION}-imagick \
libapache2-mod-php${PHP_VERSION}

echo "=== MySQL ==="
sudo systemctl enable mysql
sudo systemctl start mysql

echo "=== MySQL-Datenbank wird eingerichtet ==="
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

sudo systemctl restart mysql

echo "=== PHP ==="
echo "=== Eigene PHP-Konfiguration für JTL Shop wird erstellt ==="
sudo tee "$JTL_PHP_INI" > /dev/null <<EOL
; JTL Shop $JTL_VERSION PHP-Konfiguration

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

echo "=== Temporäres Verzeichnis wird erstellt ==="
mkdir -p "$TEMP_DIR"

echo "=== JTL Shop ZIP wird heruntergeladen ==="
curl -L "$JTL_ZIP_URL" -o "$TEMP_DIR/jtlshop.zip"

echo "=== JTL Systemcheck ZIP wird heruntergeladen ==="
curl -L "$TEST_SCRIPT" -o "$TEMP_DIR/systemcheck.zip"

echo "=== Erstelle web Ordner ==="
mkdir -p "$JTL_INSTALL_DIR"

echo "=== JTL Shop wird entpackt ==="
sudo unzip "$TEMP_DIR/jtlshop.zip" -d "$JTL_INSTALL_DIR"

echo "=== JTL Systemcheck wird entpackt ==="
sudo unzip "$TEMP_DIR/systemcheck.zip" -d "$JTL_INSTALL_DIR"

echo "=== Cleanup ==="
sudo rm -rf "$TEMP_DIR"

echo "=== Dateiberechtigungen werden gesetzt ==="
sudo chown -R www-data:www-data "$JTL_INSTALL_DIR"
sudo find "$JTL_INSTALL_DIR" -type d -exec chmod 755 {} \;
sudo find "$JTL_INSTALL_DIR" -type f -exec chmod 644 {} \;

echo "=== Erstelle SSL Zertifikat ==="
sudo mkdir -p /etc/ssl/$DOMAIN/private
sudo mkdir -p /etc/ssl/$DOMAIN/certs
sudo openssl req -newkey rsa:2048 -nodes -keyout "/etc/ssl/$DOMAIN/private/$KEYFILE" -x509 -days $DAYS -out "/etc/ssl/$DOMAIN/certs/$CRTFILE" -subj "/CN=$DOMAIN"

echo "=== Apache ==="
sudo systemctl enable apache2
sudo systemctl start apache2

echo "=== Apache-Module werden aktiviert ==="
sudo a2enmod rewrite deflate expires headers ssl

sudo systemctl restart apache2

echo "=== Apache Konfiguration HTTP zu HTTPS wird erstellt ==="
sudo tee "$APACHE_CONF" > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin $SERVER_ADMIN_MAIL
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

    ErrorLog \${APACHE_LOG_DIR}/jtlshop_error.log
    CustomLog \${APACHE_LOG_DIR}/jtlshop_access.log combined
</VirtualHost>
EOL

echo "=== Apache Konfiguration HTTPS wird erstellt ==="
sudo tee "$APACHE_CONF_SSL" > /dev/null <<EOL
<VirtualHost *:443>
    ServerAdmin $SERVER_ADMIN_MAIL
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    
    DocumentRoot $JTL_INSTALL_DIR
    <Directory $JTL_INSTALL_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/ssl/$DOMAIN/certs/$CRTFILE
    SSLCertificateKeyFile /etc/ssl/$DOMAIN/private/$KEYFILE

    ErrorLog \${APACHE_LOG_DIR}/jtlshop_SSL_error.log
    CustomLog \${APACHE_LOG_DIR}/jtlshop_SSL_access.log combined
</VirtualHost>
EOL

echo "=== Apache-Konfiguration wird aktiviert und 000-default deaktiviert ==="
sudo a2ensite jtlshop.conf
sudo a2ensite jtlshop-ssl.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2


if [ "$USE_UFW_FIREWALL" = true ]; then
echo "=== UFW Firewall aktivieren ==="
    sudo apt install -y ufw
    if [ "$UFW_OPEN_SSH" = true ]; then
        sudo ufw allow OpenSSH
    fi
    if [ "$UFW_OPEN_APACHE" = true ]; then
        #sudo ufw allow 'Apache Full'
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
    fi
    sudo ufw enable
    sudo ufw status verbose
fi

echo ">> "
echo ">> "
echo "=== Installation abgeschlossen ==="
echo " "
echo ">> Öffne im Browser: https://$DOMAIN/systemcheck zur Prüfung des JTL Shop Systems"
echo ">> Bitte lösche nach dem Systemcheck den Ordner $JTL_INSTALL_DIR/systemcheck"
echo ">> sudo rm -rf $JTL_INSTALL_DIR/systemcheck"
echo " "
echo " "
echo ">> Öffne im Browser: https://$DOMAIN/install zur JTL Shop Einrichtung"
echo " "
echo ">> Datenbank benutzer: $DB_USER"
echo ">> Datenbank password: $DB_PASS"
echo ">> Datenbank name: $DB_NAME"
echo ">> Datenbank host: localhost"
echo " "
echo ">> SSL Zertifikate"
echo ">> SSLCertificateFile /etc/ssl/$DOMAIN/certs/$CRTFILE "
echo ">> SSLCertificateKeyFile /etc/ssl/$DOMAIN/private/$KEYFILE "
