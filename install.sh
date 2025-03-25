#!/usr/bin/env bash

echo ""
echo "#########################################################################"
echo ""
echo "Enter the password you want to use for MySQL root: "
read rootpass
echo ""
echo "Enter the password you want to use for Stalker to connect to MySQL: "
read stalkerpass
echo ""

# Asking for Ministra version
while true; do
    read -p "Do you want to install Ministra directly from their servers? " yn
        [Yy]* ) ministra_source=http://download.ministra.com/downloads/159934057961c4dfe9153ee02d7e3fb1/ministra-5.6.10.zip; break;;
        [Nn]* ) ministra_source=http://download.ministra.com/downloads/159934057961c4dfe9153ee02d7e3fb1/ministra-5.6.9.zip; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo ""
echo "#########################################################################"
echo ""

echo "Setting locales..."
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "Setting up PHP 7.0 Repository..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y

echo "Running Apt Update & Upgrade..."
sudo apt-get update && sudo apt-get upgrade -y

echo "Installing Initial Packages..."
sudo apt-get install -y dialog net-tools wget git curl \
nano sudo unzip sl lolcat software-properties-common \
aview

echo "Installing Nginx..."
sudo apt-get install nginx nginx-extras -y
sudo /etc/init.d/nginx stop

echo "Installing Apache2..."
sudo apt-get install apache2 -y
sudo /etc/init.d/apache2 stop

echo "Installing Additional Packages..."
sudo apt-get install -y php7.0-dev php7.0-mcrypt php7.0-intl \
php7.0-mbstring php7.0-zip memcached php7.0-memcache \
php7.0 php7.0-xml php7.0-gettext php7.0-soap php7.0-mysql \
php7.0-geoip php-pear nodejs libapache2-mod-php php7.0-curl \
php7.0-imagick php7.0-sqlite3 unzip

echo "Changing PHP Version..."
sudo update-alternatives --set php /usr/bin/php7.0

echo "Installing Phing..."
sudo pear channel-discover pear.phing.info
sudo pear install phing/phing-2.15.0

echo "Installing npm 2.5.11..."
sudo apt-get install npm -y
sudo npm config set strict-ssl false
sudo npm install -g npm@2.15.11
sudo ln -s /usr/bin/nodejs /usr/bin/node

echo "Configuring Timezone..."
sudo ln -fs /usr/share/zoneinfo/Europe/London /etc/localtime
sudo dpkg-reconfigure --frontend noninteractive tzdata

echo "Installing MySQL Server ..."
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server mysql-server/root_password password $rootpass" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $rootpass" | sudo debconf-set-selections
sudo apt-get install -y mysql-server

echo "Creating MySQL Users..."
mysql -uroot -p$rootpass -e "create database stalker_db;"
mysql -uroot -p$rootpass -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${rootpass}';"
mysql -uroot -p$rootpass -e "CREATE USER 'stalker'@'localhost' IDENTIFIED BY '${stalkerpass}';"
mysql -uroot -p$rootpass -e "GRANT ALL ON stalker_db.* TO 'stalker'@'localhost' WITH GRANT OPTION;"
mysql -uroot -p$rootpass -e "ALTER USER 'stalker'@'localhost' IDENTIFIED WITH mysql_native_password BY '${stalkerpass}';"
mysql -uroot -p$rootpass -e "FLUSH PRIVILEGES;"

echo "Configuring MySQL..."
echo 'sql_mode=""' | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'extension=geoip.so' | sudo tee -a /etc/php/7.0/apache2/php.ini
echo 'default_authentication_plugin=mysql_native_password' | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart

echo "Installing Ministra..."
cd /var/www/html/
wget $ministra_source
unzip ministra-5.6.9.zip
rm -rf *.zip
rm /var/www/html/index*
touch /var/www/html/index.php
echo '<?php' | sudo tee -a /var/www/html/index.php
echo 'header("Location:stalker_portal/c/");' | sudo tee -a /var/www/html/index.php
echo '?>' | sudo tee -a /var/www/html/index.php

echo "Configuring PHP..."
sudo sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php/7.0/apache2/php.ini
sudo ln -s /etc/php/7.0/mods-available/mcrypt.ini /etc/php/8.1/mods-available/
sudo a2dismod mpm_event
sudo a2enmod php7.0
sudo phpenmod mcrypt
sudo a2enmod rewrite
sudo apt-get purge libapache2-mod-php5filter > /dev/null

echo "Setting up Apache2 Config File..."
cd /etc/apache2/sites-enabled/
sudo rm -rf *
wget https://files.scripting.online/ministra_569/000-default.conf
cd /etc/apache2/
sudo rm -rf ports.conf
wget https://files.scripting.online/ministra_569/ports.conf

echo "Setting up Nginx Config File..."
cd /etc/nginx/sites-available/
sudo rm -rf default
wget https://files.scripting.online/ministra_569/default

echo "Restarting Apache2 & Nginx..."
sudo /etc/init.d/apache2 restart
sudo /etc/init.d/nginx restart

echo "Fixing Smart Launcher..."
sudo mkdir /var/www/.npm
sudo chmod 777 /var/www/.npm

echo "Patching Composer..."
cd /var/www/html/stalker_portal/deploy
wget https://files.scripting.online/ministra_569/composer_version_1.9.1.patch
sudo patch build.xml < composer_version_1.9.1.patch
sudo rm composer_version_1.9.1.patch

echo "Installing custom.ini..."
cd /var/www/html/stalker_portal/server
wget -O custom.ini https://files.scripting.online/ministra_569/custom.ini

echo "Running Phing..."
sudo sed -i "s/mysql_pass = 1/mysql_pass = $stalkerpass/g" /var/www/html/stalker_portal/server/config.ini
sudo sed -i "s/mysql -u root -p mysql/mysql -u root -p$rootpass mysql/g" /var/www/html/stalker_portal/deploy/build.xml
git config --global http.sslVerify "false"
cd /var/www/html/stalker_portal/deploy
sudo phing
git config --global --unset http.sslVerify
sudo sed -i "s/mysql -u root -p$rootpass mysql/mysql -u root -p mysql/g" /var/www/html/stalker_portal/deploy/build.xml

echo ""
echo "Done!"
