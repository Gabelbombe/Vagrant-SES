#!/usr/bin/env bash
#
# Right now this will install php 5.4, and mysql 5.5
# I will need to change this to php 5.3 and mariadb
# we will also need to create the clone_dir inside of
# /vagrant/httpdocs of the git_url, as well as load
# the database, clean mage_root/var/* and whatever
# else comes up....
export DEBIAN_FRONTEND=noninteractive

# Install Apache & PHP 5.4+
# --------------------
apt-get install -y apache2
apt-get install -y php5
apt-get install -y libapache2-mod-php5
apt-get install -y php5-mysqlnd php5-curl php5-xdebug php5-gd php-pear php5-imap php5-mcrypt php5-sqlite php5-tidy php5-xmlrpc php5-xsl php-soap

php5enmod mcrypt

# Install GIT
apt-get install -y git

# Delete default apache web dir and symlink mounted vagrant dir from host machine
# --------------------
rm -rf /var/www/html /vagrant/httpdocs

mkdir -p /vagrant/httpdocs

ln -fs /vagrant/httpdocs /var/www/html

# Replace contents of default Apache vhost
# --------------------
VHOST=$(cat <<EOF
Listen 8080
<VirtualHost *:80>
  DocumentRoot "/var/www/html/public"
  ServerName localhost
  <Directory "/var/www/html/public">
    AllowOverride All
  </Directory>
</VirtualHost>
<VirtualHost *:8080>
  DocumentRoot "/var/www/html/public"
  ServerName localhost
  <Directory "/var/www/html/public">
    AllowOverride All
  </Directory>
</VirtualHost>
EOF
)

echo "$VHOST" > /etc/apache2/sites-enabled/000-default.conf

a2enmod rewrite
service apache2 restart

# MariaDB
# --------------------
# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive

apt-get -q -y install mysql-server-5.5

sed -ie 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
service mysql restart

# Create a God mode user
mysql -u root -e "CREATE USER 'god'@'localhost'"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'god'@'localhost' WITH GRANT OPTION"

mysql -u root -e "CREATE USER 'god'@'%'"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'god'@'%' WITH GRANT OPTION"

mysql -u root -e "FLUSH PRIVILEGES"

# Adding OR Magento site
su vagrant -c "
  git clone git@github.com:engrade/engrade-queue.git /vagrant/httpdocs/
"

cd /tmp
apt-get install -y unzip

curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip

./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

mkdir -p '/home/vagrant/.aws'

# Set up AWS config stuff
echo -e '[default]\noutput = json\nregion = us-east-1' > /home/vagrant/.aws/config
echo -e '[default]\naws_access_key_id = AKIAIYBPLLDG63BQSLRQ\naws_secret_access_key = 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' > /home/vagrant/.aws/credentials
chown -r vagrant:vagrant /home/vagrant/.aws

su vagrant -c "
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
"

## Cleanup
rm -fr /tmp/*

## Test AWS Access keys
aws configure