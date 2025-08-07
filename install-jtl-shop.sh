#!/bin/bash
#
## Version 1.1.0 by Developers Garden (www.devgarden.de)
# 

set -e      # Stoppe Script bei Fehler

# === Konfiguration ===
while true; do
    read -p "Bitte geben Sie die domain ohne www ein (example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo "Fehler: Domain darf nicht leer sein!"
    else
        break
    fi
done

# Domain, Server & email
#DOMAIN="example.com"
SERVER_ADMIN_MAIL="admin@$DOMAIN"
SET_TIMEZONE="Europe/Berlin"

#EMAIL="webmaster@example.com"
EMAIL=$SERVER_ADMIN_MAIL

# SSL Zertifikat
read -p "Nutzen Sie ein Reverse Proxy Manager? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[YyJj]$ ]] && [[ ! -z $REPLY ]]; then
    USE_CERTBOT="false"
else
    USE_CERTBOT="true"
fi

# MySQL Datenbank
DB_HOST="localhost"
DB_NAME="jtlshop"
DB_USER="jtluser"
DB_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

# Admin und Sync Benutzer
ADMIN_USER="admin"
ADMIN_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
SYNC_USER="jtlsync"
SYNC_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

## JTL Version
JTL_VERSION="v5-5-2"
JTL_ZIP_URL="https://build.jtl-shop.de/get/shop-$JTL_VERSION.zip"
TEST_SCRIPT="https://build.jtl-shop.de/get/shop5-systemcheck-5-0-0.zip"

# PHP
PHP_VERSION="8.2"
JTL_PHP_INI="/etc/php/${PHP_VERSION}/apache2/conf.d/99-jtl-shop-$JTL_VERSION.ini"
MAX_EXECUTION_TIME="120"        # Maximale Ausführungszeit eines PHP-Skripts in Sekunden.
MEMORY_LIMIT="128M"             # Maximale Speichernutzung pro PHP-Skript.
UPLOAD_MAX_FILE_SIZE="6M"       # Maximale Größe einer hochgeladenen Datei.
POST_MAX_SIZE="8M"              # Maximale Größe der gesamten POST-Daten.

# Apache 
APACHE_CONF="/etc/apache2/sites-available/jtlshop.conf"
APACHE_CONF_SSL="/etc/apache2/sites-available/jtlshop-ssl.conf"
JTL_INSTALL_DIR="/var/www/html/jtlshop-$JTL_VERSION"

# UFW Firewall
USE_UFW_FIREWALL="false"    # UFW Firewall installieren und Aktivieren?
UFW_OPEN_SSH="true"         # Erlaube SSH, damit du nicht ausgesperrt wirst!
UFW_OPEN_APACHE="true"      # Öffnet Ports 80 & 443 über die Apache2 Gruppe

# Scripthelfer
TEMP_DIR="$PWD/jtlshop_download"

# Selbst seginiertes Zertifkat (Nur bei Reverse Proxy einsatz)
DAYS=3650                   # 365 Tage/Jahr * 10 Jahre = 3650 Tage Gültig
KEYFILE="${DOMAIN}.key"
CRTFILE="${DOMAIN}.crt"
RSA_KEY_SIZE="4096"         # 2048 oder 4096 bit Schlüssellänge

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
sudo systemctl enable mysql && sudo systemctl start mysql

echo "=== MySQL-Datenbank wird eingerichtet ==="
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

sudo systemctl restart mysql

echo "=== Eigene PHP-Konfiguration für JTL Shop $JTL_VERSION wird erstellt ==="
sudo tee "$JTL_PHP_INI" > /dev/null <<EOL
; JTL Shop $JTL_VERSION PHP-Konfiguration

max_execution_time = ${MAX_EXECUTION_TIME}
memory_limit = ${MEMORY_LIMIT}
upload_max_filesize = ${UPLOAD_MAX_FILE_SIZE}
post_max_size = ${POST_MAX_SIZE}
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

echo "=== Temporäres Installationsverzeichnis wird erstellt ==="
mkdir -p "$TEMP_DIR"

echo "=== JTL Shop $JTL_VERSION ZIP wird heruntergeladen ==="
curl -L "$JTL_ZIP_URL" -o "$TEMP_DIR/jtlshop.zip"

echo "=== JTL Systemcheck ZIP wird heruntergeladen ==="
curl -L "$TEST_SCRIPT" -o "$TEMP_DIR/systemcheck.zip"

echo "=== Erstelle webroot Ordner ==="
mkdir -p "$JTL_INSTALL_DIR"

echo "=== JTL Shop $JTL_VERSION wird entpackt ==="
sudo unzip "$TEMP_DIR/jtlshop.zip" -d "$JTL_INSTALL_DIR"

echo "=== JTL Systemcheck wird entpackt ==="
sudo unzip "$TEMP_DIR/systemcheck.zip" -d "$JTL_INSTALL_DIR"

echo "=== Cleanup - Entferne Temoräres Verzeichniss ==="
sudo rm -rf "$TEMP_DIR"

echo "=== Dateiberechtigungen werden gesetzt ==="
sudo chown -R www-data:www-data "$JTL_INSTALL_DIR"
sudo find "$JTL_INSTALL_DIR" -type d -exec chmod 755 {} \;
sudo find "$JTL_INSTALL_DIR" -type f -exec chmod 644 {} \;

echo "=== Richte Apache vhost Port 80 ein ==="
sudo systemctl enable apache2
sudo systemctl start apache2
sudo a2enmod rewrite deflate expires headers ssl
sudo a2dissite 000-default.conf

sudo tee "$APACHE_CONF" > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin $SERVER_ADMIN_MAIL
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN

    DocumentRoot $JTL_INSTALL_DIR
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

    ErrorLog \${APACHE_LOG_DIR}/jtlshop_error.log
    CustomLog \${APACHE_LOG_DIR}/jtlshop_access.log combined
</VirtualHost>
EOL

sudo a2ensite jtlshop.conf

echo "=== Erstelle SSL Zertifikat && Apache SSL vHost ==="
if [ "$USE_CERTBOT" = true ]; then
    echo "=== Certbot Zertifikat anfordern & Apache konfigurieren ==="
    sudo apt install python3 python3-dev python3-venv libaugeas-dev gcc
    sudo python3 -m venv /opt/certbot/
    sudo /opt/certbot/bin/pip install --upgrade pip
    sudo /opt/certbot/bin/pip install certbot certbot-apache
    sudo certbot --apache -d "$DOMAIN" -d "www.$DOMAIN" --redirect --agree-tos -m "$EMAIL" --non-interactive
    echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
else
    echo "=== Selbst segnierte Zertifikate für Reverse Proxy ==="
    sudo mkdir -p /etc/ssl/$DOMAIN/private
    sudo mkdir -p /etc/ssl/$DOMAIN/certs
    sudo openssl req -newkey rsa:$RSA_KEY_SIZE -nodes -keyout "/etc/ssl/$DOMAIN/private/$KEYFILE" -x509 -days $DAYS -out "/etc/ssl/$DOMAIN/certs/$CRTFILE" -subj "/CN=$DOMAIN"

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

sudo a2ensite jtlshop-ssl.conf

fi

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
echo "=== Basis Installation abgeschlossen ==="
echo " "
echo ">> Öffne Sie im Browser: https://$DOMAIN/systemcheck zur Prüfung des JTL Shop Systems"
echo ">> "

read -p "Systemcheck war korrekt? [Y/n] " -n 1 -r
echo  # Zeilenumbruch nach Eingabe
if [[ $REPLY =~ ^[YyJj]$ ]] && [[ ! -z $REPLY ]]; then
    sudo rm -rf $JTL_INSTALL_DIR/systemcheck
else
    echo ">> Anscheinend gibt es ein Fehler im Script. "
    echo ">> Bitte kontaktieren Sie uns! "
fi

sudo -u www-data php "$JTL_INSTALL_DIR/cli" shop:install \
    --shop-url="https://$(DOMAIN -f)" \
    --database-host="$DB_HOST" \
    --database-name="$DB_NAME" \
    --database-user="$DB_USER" \
    --database-password="$DB_PASS" \
    --admin-user="$ADMIN_USER" \
    --admin-password="$ADMIN_PASS" \
    --sync-user="$SYNC_USER" \
    --sync-password="$SYNC_PASS" \
    --file-owner="www-data" \
    --file-group="www-data"

echo " === Entferne install verzeichniss und korrigiere Dateirechte ==="
sudo chmod 644 $JTL_INSTALL_DIR/includes/config.JTL-Shop.ini.php
sudo rm -rf $JTL_INSTALL_DIR/install


echo " "
echo " === Bitte notieren Sie sich die Zugangsdaten!"
echo " "
echo "## Hauptbenutzer "
echo " "
echo ">> Admin Benutzer: $ADMIN_USER"
echo ">> Admin Password: $ADMIN_PASS"
echo " "
echo "## Benutzer für die Syncronisation zwischen JTL Shop & JTL Wawi  "
echo " "
echo ">> JTL WAWI Sync Benutzer: $SYNC_USER"
echo ">> JTL WAWI Sync Benutzer: $SYNC_PASS"
echo " "
echo "## MySQL Dantenbank (mariadb) "
echo " "
echo ">> Datenbank benutzer: $DB_USER"
echo ">> Datenbank password: $DB_PASS"
echo ">> Datenbank name: $DB_NAME"
echo ">> Datenbank host: $DB_HOST"
echo " "
echo " "
echo " ## Ihr Onlineshop $DOMAIN ist einsatzbereit "
echo " "
echo " Onlineshop "
echo " https://$DOMAIN/ "
echo " "
echo " Administrations backend "
echo " https://$DOMAIN/admin "
echo " "
echo " "
echo " Fahren Sie mit der Grundkonfiguration fort " 
echo " https://guide.jtl-software.com/jtl-shop/jtl-shop-kauf-editionen/grundkonfiguration-vornehmen/ "
echo " "