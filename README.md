# 🛒 JTL Shop 5 Install Script

Automatisiertes Installationsscript für **JTL Shop 5** auf **Ubuntu/Debian**-basierten Servern.

---

## 🛠️ Was macht das Script?

- Aktualisiert dein System
- Installiert Apache, MySQL, PHP 8.x und alle nötigen PHP-Module
- Erstellt eine spezifische php.ini für JTL Shop 5
- Aktiviert Apache-Module (rewrite, headers, etc.)
- Lädt JTL Shop 5 und das Systemcheck-Tool
- Entpackt und kopiert die Dateien nach /var/www/html/jtlshop-$VERSION
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
Bitte lies dir das Script erst durch. Führe nie Scripte aus ohne sie gelesen zu haben!

### 3. Script ausführbar machen
```bash
chmod +x install.sh
```
### 4. Script ausführen
```bash
sudo ./install.sh
```
> Kaffee holen!


## 🛡️ Lizenz

Dieses Projekt steht unter der GNU Public license.

## 👨‍💻 Credits

Erstellt von Developers Garden 

Website: (https://devgarden.de)

GitHub: https://github.com/devgarden-de


## 💬 Feedback oder Fehler melden?

Erstelle ein Issue oder sende eine Pull Request.

Wir freuen uns über jedes Feedback und jeden Beitrag!