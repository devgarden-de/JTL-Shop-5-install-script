# Under construction!!!


# 🛒 JTL Shop 5 Install Script

Automatisiertes Installationsscript für **JTL Shop 5** auf **Ubuntu/Debian**-basierten Servern.

---

## 🛠️ Was macht das Script?

- Aktualisiert dein System
- Installiert Apache, MySQL, PHP 8.x und alle nötigen PHP-Module
- Erstellt eine spezifische php.ini für JTL Shop 5
- Aktiviert Apache-Module (rewrite, headers, etc.)
- Lädt JTL Shop 5 und das Systemcheck-Tool herunter
- Entpackt und kopiert die Dateien nach /var/www/html/jtlshop
- Setzt die Dateiberechtigungen
- Legt eine Datenbank an
- Erstellt eine Apache-Konfiguration mit deiner Domain
- Erstellt SSL Zertifikate über Let's Encrypt - (Optional) 
- Läd Firewall und konfiguriert diese - (Optional) 


## 🚀 Installation

### 1. Repository klonen

```bash
git clone https://github.com/devgarden-de/JTL-Shop-5-install-script.git
```
```bash
cd JTL-Shop-5-install-script
```

### 2. Script anpassen
Voreinstellungen im Script
```bash
DOMAIN="example.com"
DB_NAME="jtlshop"
DB_USER="jtluser"
DB_PASS="sicherespasswort"
SERVER_ADMIN_MAIL="webadmin@localhost"
```
Diese Daten kannst du im ``install.sh`` nach deinen Wünschen anpassen.

```bash
nano install.sh
```
Passe ``DOMAIN``, ``DB_USER``, ``DB_PASS``, ``JTL_VERSION``, etc. nach Bedarf an.

### 3. Script ausführbar machen
```bash
chmod +x install.sh
```
### 4. Script ausführen
```bash
sudo ./install.sh
```
> Kaffee holen!

## 5. Installation Abschlissen

Öffne im Browser: https://deine-domain.de/systemcheck zur Prüfung des JTL Shop Systems.

> Bitte lösche nach der Prüfung den Ordner ``/var/www/html/jtlshop/systemcheck``

```bash
sudo rm -rf /var/www/html/jtlshop/systemcheck
```

Öffne im Browser: https://deine-domain.de/install und schliße deine JTL Shop Einrichtung ab!

## 👨‍💻 Unterstützte Betriebssysteme

    ✅ Ubuntu >= 20.04 
    ✅ Debian >= 10

## 📁 Projektstruktur
```bash
JTL-Shop-5-install-script/
│
├── install.sh       # Haupt-Installationsscript
├── README.md        # Diese Datei
```

## 🛡️ Lizenz

Dieses Projekt steht unter der MIT License – siehe LICENSE Datei für weitere Informationen.

## 👨‍💻 Credits

Erstellt von Developers Garden

GitHub: https://github.com/devgarden-de


## 💬 Feedback oder Fehler melden?

Erstelle ein Issue oder sende eine Pull Request.

Wir freuen uns über jedes Feedback und jeden Beitrag!