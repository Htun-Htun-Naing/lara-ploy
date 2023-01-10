#!/bin/bash

# Update the system and install necessary packages
sudo yum update -y
# sudo yum install -y git composer nginx

# Install PHP and required extensions
sudo amazon-linux-extras install nginx1
sudo amazon-linux-extras enable php8.0
sudo yum install -y composer nginx git 
sudo yum install -y php php-cli php-mysqlnd php-pdo php-common php-fpm 
sudo yum install -y php-gd php-mbstring php-xml php-dom php-intl php-simplexml 
# sudo yum install -y php php-fpm php-cli php-mbstring php-xml php-zip

### Install MySQL and set the root password
# sudo yum install -y mysql-server
# sudo service mysqld start
# sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YOUR-PASSWORD';"

### Clone the repository and install dependencies
# git clone https://github.com/your-username/your-repository.git
# cd your-repository
# composer install

#Install new project from composer (testing only)


#composer install

EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
then
    >&2 echo 'ERROR: Invalid installer checksum'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
RESULT=$?

rm composer-setup.php

sudo mv composer.phar /usr/local/bin/composer

sudo chown -R ec2-user:ec2-user /var/www/html 
sudo chmod -R 755 /var/www/html 
cd /var/www/html 
composer create-project laravel/laravel:^8.0 larapp
cd larapp
# Copy the .env.example file and set the necessary environment variables
cp .env.example .env
sed -i 's/DB_DATABASE=homestead/DB_DATABASE=YOUR-DATABASE-NAME/' .env
sed -i 's/DB_USERNAME=homestead/DB_USERNAME=root/' .env
sed -i 's/DB_PASSWORD=secret/DB_PASSWORD=YOUR-MYSQL-PASSWORD/' .env

# Generate an application key
php artisan key:generate

# Create the database and run migrations
# php artisan migrate

# Install npm dependencies and build the assets
# npm install
# npm run production
composer install 
# Set up the nginx configuration
sudo chmod -R u+w /etc/nginx/nginx.conf
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

sudo bash -c 'cat > /etc/nginx/nginx.conf' <<EOL
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load balanced upstream configuration
    upstream app {
        server unix:/var/run/php-fpm/www.sock;
    }

    server {
        listen 80;
        # server_name _;
        root /var/www/html/larapp/public;

        index index.php;

        add_header X-Frame-Options "SAMEORIGIN";

# Set up the nginx configuration (continued)

location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
}

location ~ \.php$ {
    fastcgi_pass app;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
}

location ~ /\.(?!well-known).* {
    deny all;
}
}
}
EOL

# Set the correct ownership and permissions
sudo chown -R nginx:nginx /var/www/html/larapp
sudo chmod -R 755 /var/www/html/larapp
sudo chmod -R 777 /var/www/html/larapp/storage
# Start the web server and enable it to start on boot
sudo service nginx start
sudo systemctl enable nginx

# Start PHP-FPM and enable it to start on boot
sudo service php-fpm start
sudo systemctl enable php-fpm
