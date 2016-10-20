#!/bin/bash

##
# SET PASSWORD FOR MYSQL IN MAGENTO INSTALL ALSO SET BASE URL
##
read -e -p "Enter Magento 2 Versions: " -i "2.1.2" MAGEVSERION
read -e -p "Enter the base url (without http(s)://): " -i "localhost" BASEURL

# Run the script as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

##
# Don't edit underneath this line
##
DBUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
DBPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

echo "STEP 1"
apt-get -qq update
apt-get -qq -y install mysql-server mysql-client apache2 libapache2-mod-fastcgi mysql-server php libapache2-mod-php mysql-server php-mysql php-dom php-simplexml php-curl php-intl php7.0-gd php7.0-mcrypt php-xsl php-mbstring php-zip php-xml composer python-letsencrypt-apache unzip
apt install -y mcrypt
a2enmod rewrite
service php7.0-fpm restart
service mysql restart

echo "STEP 2"
cd ~
git clone git://github.com/phpenv/phpenv.git .phpenv
echo 'export PATH="$HOME/.phpenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(phpenv init -)"' >> ~/.bash_profile
phpenv rehash
cp ~/.phpenv/versions/$(~/.phpenv/bin/phpenv version-name)/etc/php-fpm.d/www.conf.default ~/.phpenv/versions/$(~/.phpenv/bin/phpenv version-name)/etc/php-fpm.d/www.conf 2>/dev/null || true

echo "STEP 3"
a2enmod rewrite actions fastcgi alias

echo "STEP 4"
mkdir -p /var/www && chmod 777 /var/www && cd /var/www
wget https://github.com/magento/magento2/archive/${MAGEVSERION}.tar.gz
tar -xzf ${MAGEVSERION}.tar.gz
mv magento2-${MAGEVSERION}/ magento2/

echo "STEP 5"
cd /var/www
git clone https://github.com/magento/magento2-sample-data.git
cd magento2-sample-data/dev/tools
php -f build-sample-data.php -- --ce-source="/var/www/magento2"

echo "STEP 6"
cd /var/www/magento2
composer install
chmod +x /var/www/magento2/bin/magento

echo "STEP 7"
mysql -u root -e "create database magentodb; GRANT ALL PRIVILEGES ON magentodb.* TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}'" -p

echo "STEP 8"
cd /var/www/magento2
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;
find ./var -type d -exec chmod 777 {} \;
find ./var -type f -exec chmod 777 {} \;
find ./pub/media -type d -exec chmod 777 {} \;
find ./pub/static -type d -exec chmod 777 {} \;
chmod 777 ./app/etc
chmod 644 ./app/etc/*.xml
chmod u+x bin/magento

echo "STEP 9"
/var/www/magento2/bin/magento setup:install --backend-frontname="adminlogin" --db-host="127.0.0.1" --db-name="magentodb" --db-user="${DBUSER}" --db-password="${DBPASS}" --language="en_US" --currency="USD" --timezone="America/New_York" --use-rewrites=1 --use-secure=1 --base-url="http://${BASEURL}" --base-url-secure="https://${BASEURL}" --admin-user=adminuser --admin-password=admin123@ --admin-email=admin@newmagento.com --admin-firstname=admin --admin-lastname=user --cleanup-database
cd /var/www/magento2
find ./var -type d -exec chmod 777 {} \;
find ./var -type f -exec chmod 777 {} \;

echo "STEP 10"
mysql -u ${DBUSER} -p${DBPASS} -e 'USE magentodb; REPLACE INTO core_config_data (path, value) VALUES("webapi/webapisecurity/allow_insecure", 1);'

echo "STEP 11"
cd /var/www/magento2/app/code/Magento
wget https://github.com/dorel/Magento2-extension/archive/master.zip
unzip master.zip
rm master.zip
mv Magento2-extension-master/Disabled-frontend ./
rm -r Magento2-extension-master/

echo "STEP 12"
/var/www/magento2/bin/magento cache:clean
/var/www/magento2/bin/magento cache:flush

echo "STEP 13"
rm /etc/apache2/sites-available/000-default.conf
wget https://raw.githubusercontent.com/bobvanluijt/magento2-sample-REST-setup-bash/master/apache-config -O /etc/apache2/sites-available/000-default.conf
sed -i "s/UPDATE_TO_WEBSITE/${BASEURL}/g" /etc/apache2/sites-available/000-default.conf

echo "STEP 14"
letsencrypt --apache
letsencrypt renew --dry-run --agree-tos

echo "STEP 15"
service apache2 restart

echo "LOGIN: /adminlogin User: adminuser Pass: admin123@"
