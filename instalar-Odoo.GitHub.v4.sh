#!/bin/bash

OE_SUPERADMIN="admin_odoo"
ODOODIR="/opt/odoo/v8"
OE_CONFIG="odoo.v8.conf"
SYS_USER=$(id -un)
OE_LAUNCHD="com.odoo-server.v8.plist"

function OCA {
	cd $ODOODIR
	rm -rf /opt/odoo/v8/$1
	git clone -b 8.0 https://github.com/OCA/$1.git $ODOODIR/$1
	find $ODOODIR/$1/ -type d -depth 1 -not -name "\.*" -not -name "setup" -exec ln -sfF {} $ODOODIR/other-addons/ ';'
}

read -s -p "Contraseña de administrador: " CLAVE
echo "
iniciando Instalación
"

## Primero instalamos el gestor de paquetes homebrew
## Este nos instalará también el compilador en CLI y GIT
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Creamos los directorios de trabajo para Odoo, y ajustamos los permisos
echo "$CLAVE" | sudo -S mkdir -p $ODOODIR/other-addons
echo "$CLAVE" | sudo -S chmod -R a+rw /opt/odoo/v8
echo "$CLAVE" | sudo -S chown -R 501:20 /opt/odoo/v8

# Creamos el directorio de salida para los registros de actividad, y ajustamos los permisos
echo "$CLAVE" | sudo -S mkdir -p /var/log/odoo
echo "$CLAVE" | sudo -S chmod a+w /var/log/odoo

## Instalamos una versión propia de Python y descartamos la del sistema por problemas con SIP
## así también evitamos esas actualizaciones "rompedoras" por parte de Apple
echo "$CLAVE" | sudo -S export PATH=/usr/local/bin:$PATH
brew install python
brew linkapps python
echo "$CLAVE" | sudo -S export PYTHON_PATH=$(which python)

## necesitamos un sistema de descarga de archivos via http/https
## curl no nos sirve por el problema con los certificados autofirmados
brew install wget

# Iniciamos la instalación de los módulos para Odoo
# son repositorios git en github con funcionalidades varias
# ... has de comentar o eliminar los que pienses no sean necesarios
OCA account-closing
OCA account-financial-reporting
OCA account-financial-tools
OCA account-invoicing
OCA account-payment
OCA bank-payment
OCA bank-statement-import
OCA bank-statement-reconcile
OCA contract
OCA crm
OCA hr
OCA knowledge
OCA l10n-spain
OCA partner-contact
OCA pos
OCA product-attribute
OCA project
OCA project-reporting
OCA reporting-engine
OCA rma
OCA sale-workflow
OCA server-tools
OCA social
OCA stock-logistics-tracking
OCA stock-logistics-warehouse
OCA stock-logistics-workflow
OCA web

## BASE ODOO
git clone -b 8.0 https://github.com/OCA/OCB.git $ODOODIR/OCB

# Nos situamos en le directorio de other-addons
cd $ODOODIR/other-addons

## Iniciamos la instalación del servidor PostgreSQL v9.4.x
brew install postgresql
brew services start postgresql

# instalamos lsusb + libusb (posible solución para el módulo POS / hw_escpos)
# Nos permite utilizar la modalidad Posbox-Less del TPV
brew tap jlhonora/lsusb
brew install lsusb
brew install libusb
brew link --overwrite libusb
brew install libusb-compat

# Dependencias varias
brew install poppler
brew install librsvg
brew cask install pdftotext

echo "$CLAVE" | sudo -S pip install pyserial
echo "$CLAVE" | sudo -S sudo pip install pyusb==1.0.0b1

## Ya podemos iniciar la instalación de las dependencias directas de Odoo
echo "$CLAVE" | sudo -S pip install babel Cython psycopg2 lxml simplejson reportlab werkzeug PyYAML unittest2 mako psutil requests jinja2 docutils pypdf pysftp jcconv qrcode utils vatnumber PyWebDAV unicodecsv passlib pyusb vobject libusb1 gdata python-openid greenlet soappy unidecode decorator xlrd xlwt unicodecsv pydot django-debug-toolbar feedparser pygeoip parsing gntp ydbf parsing pytz dateutils cairosvg barcode six pycrypto

# Creamos el usuario de Odoo para PostgreSQL
createuser -s odoo

## Nos desplazamos a la carpeta temporal para evitar posible problemas
cd /private/tmp

# o en su defecto directamente de las fuentes ya sea con git o wget
wget http://download.gna.org/pychart/PyChart-1.39.tar.gz
tar xzf ./PyChart-1.39.tar.gz
cd PyChart-1.39
echo "$CLAVE" | sudo -S python setup.py install
cd ..
echo "$CLAVE" | sudo -S rm -rf ./PyChart-1.39*

wget https://pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz
tar xzf ./six-1.10.0
cd six-1.10.0
echo "$CLAVE" | sudo -S python setup.py install
cd ..
echo "$CLAVE" | sudo -S rm -rf ./six-1.10.0*

# Creamos el ficheros de configuración y carga de Odoo
echo "$CLAVE" | sudo -S printf "[options]
admin_passwd = %s
db_host = localhost
db_port = 5432
db_user = odoo
unaccent = true
db_password = false
logfile = /var/log/odoo/odoo-server.v8.log
logrotate = true
addons_path = %s/other-addons,%s/OCB/addons,%s/OCB/openerp/addons
xmlrpc_port = 8069" $OE_SUPERADMIN $ODOODIR $ODOODIR $ODOODIR > /tmp/$OE_CONFIG
echo "$CLAVE" | sudo -S mv /tmp/$OE_CONFIG /etc/
echo "$CLAVE" | sudo -S chown 0:0 /etc/$OE_CONFIG

# Creamos el fichero de carga Launchd
echo "$CLAVE" | sudo -S printf '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Disabled</key>
	<false/>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:</string>
		<key>PY_USE_XMLPLUS</key>
		<string></string>
	</dict>
	<key>GroupName</key>
	<string>staff</string>
	<key>Label</key>
	<string>com.openerp.openerpserver</string>
	<key>OnDemand</key>
	<false/>
	<key>ProgramArguments</key>
	<array>
		<string>%s</string>
		<string>%s/OCB/openerp-server</string>
		<string>-c</string>
		<string>/etc/%s</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>ServiceDescription</key>
	<string>OpenERP Server</string>
	<key>UserName</key>
	<string>%s</string>
</dict>
</plist>' $(which python) $ODOODIR $OE_CONFIG $SYS_USER > /tmp/$OE_LAUNCHD
echo "$CLAVE" | sudo -S mv /tmp/$OE_LAUNCHD /Library/LaunchDaemons/
echo "$CLAVE" | sudo -S chown 0:0 /Library/LaunchDaemons/$OE_LAUNCHD
# Cargamos Odoo
echo "$CLAVE" | sudo -S launchctl load /Library/LaunchDaemons/$OE_LAUNCHD

open http://localhost:8069
