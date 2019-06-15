#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 4)
reset=$(tput sgr0)
ip_address="127.0.0.1"
mysqlusr="phpmyadmin"
mysqlpass="root"
user=$USER
unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)    machine=Mac;;
    Linux*)     machine=Linux;;
    CYGWIN*)    machine=Cygwin;;
    *)          machine="UNKNOWN:${unameOut}"
esac
if [ ${machine} == "Darwin" ]
then
    echo -e "${blue}Hello ${user}, I will create a vitual host on your apache server on path: /Users/${user}/Sites/ \n ${green}Enter your desired name, ex: [yourdomain.test]${reset}"
    read ans
    if [ ! -z "$ans" ]; then
        matches_in_vhosts="$(grep -n $ans /etc/apache2/extra/httpd-vhosts.conf | cut -f1 -d ' ')"
        if [ ! -z "$matches_in_vhosts" ]; then
            echo -e "${green}Apache VirtualHost entry exists...! ${reset}\n "
        else
            echo -e "${green}Adding new VirtualHost. ${reset}\n "
            mkdir -p /Users/$USER/Sites/$ans
            sudo bash -c 'cat << EOF >> /etc/apache2/extra/httpd-vhosts.conf
#-------'$ans'-------
<VirtualHost *:80>
ServerAdmin admin@'$ans'
ServerName '$ans'
ServerAlias www.'$ans'
DocumentRoot /Users/'$macuser'/Sites/'$ans'
ErrorLog /Users/'$macuser'/Sites/'$ans'/error.log
CustomLog /Users/'$macuser'/Sites/'$ans'/access.log combined
</VirtualHost>
<Directory "/Users/'$macuser'/Sites/'$ans'">
AllowOverride All
Require all granted
</Directory>

EOF'
        fi
        sudo apachectl restart
        # find existing instances in the host file and save the line numbers
        matches_in_hosts="$(grep -n $ans /etc/hosts | cut -f1 -d:)"
        host_entry="${ip_address} ${ans}"

        echo -e "${green}Updating hosts file...${reset}\n "

        if [ ! -z "$matches_in_hosts" ]; then
            echo -e "${green}Host entry exists...! ${reset}\n "
        else
            echo -e "${green}Adding new hosts entry. ${reset}\n "
            echo "$host_entry" | sudo tee -a /etc/hosts >/dev/null
        fi
        # Start installing Wordpress
        echo -e "${green}Your virtual host is ready,\n do you want to install Wordpress? \n ${red}(y/n)?${reset} "
        read answer
        if [ "$answer" != "${answer#[Yy]}" ]; then
            frontDir=$(pwd)
            cd /Users/$USER/Sites/$ans
            wpDir=$(pwd)
            # Download and install wp-cli
            wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
            chmod +x wp-cli.phar
            mv wp-cli.phar /usr/local/bin/wp
            echo -e "${green}Do you have a database ready? \n ${red}(y/n)?${reset}  "
            read dbans
            if [ "$dbans" != "${dbans#[Yy]}" ]; then
                # User defined database
                echo -e "${green}What is the name of the database? ${reset} "
                read dbname
                echo -e "${green}What is the mysql username? ${reset} "
                read dbusr
                echo -e "${green}What is the mysql password? ${reset} "
                read dbpass
                wp core download --locale=en_US --force
                wp core config --dbname=$dbname --dbuser=$dbusr --dbpass=$dbpass --dbhost=localhost

            else
                # We will create a database and asign it to default user
                dbusrentry="${ans/.*/db}"
                echo -e "${green}I will create a database ${dbusrentry} with the default mysql credentials (${mysqlusr}/******). \n Make sure MYSQL exists in your environment variables!!! \nDo you want to continue \n ${red}(y/n)?${reset} "
                read nodbans
                if [ "$nodbans" != "${nodbans#[Yy]}" ]; then
                    MYSQL=$(which mysql)
                    Q1="CREATE DATABASE IF NOT EXISTS ${dbusrentry};"
                    #Q2="GRANT USAGE ON *.* TO ${mysqlusr}@localhost IDENTIFIED BY '${mysqlpass}';"
                    Q3="GRANT ALL PRIVILEGES ON ${dbusrentry}.* TO ${mysqlusr}@localhost WITH GRANT OPTION;"
                    Q4="FLUSH PRIVILEGES;"
                    SQL="${Q1}${Q3}${Q4}"

                    $MYSQL -u$mysqlusr -p$mysqlpass -e "$SQL"

                    wp core download --locale=en_US --force
                    wp config create --dbname=$dbusrentry --dbuser=$mysqlusr --dbpass=$mysqlpass --dbhost=localhost --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', false );
PHP
                    wp db drop --yes
                    wp db create
                else
                    exit
                fi
            fi
            # Wordpess is installing...
            wp core install --url=$ans --title=$ans --admin_user="admin" --admin_password="123456" --admin_email="admin@${ans}" --skip-email
            # User installs plugins
            echo -e "${green}Please enter any plugins you want to install from wordpress.org, separated by comma and no spaces \n ex: contact-form-7,wordpress-seo,clesraw3-total-cache \n (You can find the name of the plugin as slug in the url of the plugin home page \n ex: https://wordpress.org/plugins/${blue}w3-total-cache${reset}). \n ${red}Press enter if you don't want to install plugins${reset} "
            read plugins
            if [ "$plugins" != "" ]; then
                OIFS=$IFS
                IFS=','
                arr=($plugins)
                for i in "${!arr[@]}"; do wp plugin install ${arr[$i]} --activate; done
                unset IFS
            fi

            wp rewrite flush --hard

        else
            echo "Have a nice day, amigo!"
            exit
        fi
    fi
    echo -e "${green}You can visit your Wordpress admin panel at ${ans}/wp-admin, \n ${red}user name: admin, password: 123456${reset}"
    exit
elif [ ${machine} == "Linux" ]
then
    echo -e "${blue}Hello ${user}, I will create a vitual host on your apache server on path: /var/www/[yourdomain.test]/public_html \n ${green}Enter your desired name, ex: [yourdomain.test]${reset}"
    read ans
    if [ ! -z "$ans" ]; then
        echo -e "${green}Please wait while /var/www/${ans}/public_html is created and enter your password if prompted"
        sudo mkdir -p /var/www/$ans/public_html
        sudo chown -R $USER:$USER /var/www/$ans/public_html
        sudo usermod -aG www-data $USER
        sudo addgroup www-data
        sudo chmod -R 755 /var/www/$ans/public_html

        sudo bash -c 'cat << EOF > /etc/apache2/sites-available/'$ans'.conf
<VirtualHost *:80>
ServerAdmin admin@'$ans'
ServerName '$ans'
ServerAlias www.'$ans'
DocumentRoot /var/www/'$ans'/public_html
ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF'

        sudo a2ensite $ans.conf
        echo -e "${green}restarting apache...${reset}\n "
        sudo service apache2 restart
        # find existing instances in the host file and save the line numbers
        matches_in_hosts="$(grep -n $ans /etc/hosts | cut -f1 -d:)"
        host_entry="${ip_address} ${ans}"


        if [ ! -z "$matches_in_hosts" ]; then
            echo -e "${green}Host entry exists...! ${reset}\n "
        else
            echo -e "${green}Updating hosts file...${reset}\n "
            echo -e "${green}Adding new hosts entry. ${reset}\n "
            echo "$host_entry" | sudo tee -a /etc/hosts >/dev/null
        fi
    fi
    # Start installing Wordpress
    echo -e "${green}Your virtual host is ready,\n do you want to install Wordpress? \n ${red}(y/n)?${reset} "
    read answer
    if [ "$answer" != "${answer#[Yy]}" ]; then
        frontDir=$(pwd)
        cd /var/www/$ans/public_html
        wpDir=$(pwd)
        # Download and install wp-cli
        wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        sudo chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
        echo -e "${green}Do you have a database ready? \n ${red}(y/n)?${reset}  "
        read dbans
        if [ "$dbans" != "${dbans#[Yy]}" ]; then
            # User defined database
            echo -e "${green}What is the name of the database? ${reset} "
            read dbname
            echo -e "${green}What is the mysql username? ${reset} "
            read dbusr
            echo -e "${green}What is the mysql password? ${reset} "
            read dbpass
            wp core download --locale=en_US --force
            wp core config --dbname=$dbname --dbuser=$dbusr --dbpass=$dbpass --dbhost=localhost

        else
            # We will create a database and asign it to default user
            dbusrentry="${ans/.*/db}"
            echo -e "${green}I will create a database ${dbusrentry} with the default mysql credentials (${mysqlusr}/${mysqlpass}). \nDo you want to continue \n ${red}(y/n)?${reset} "
            read nodbans
            if [ "$nodbans" != "${nodbans#[Yy]}" ]; then
                MYSQL=$(which mysql)
                Q1="CREATE DATABASE IF NOT EXISTS ${dbusrentry};"
                Q2="GRANT USAGE ON *.* TO ${mysqlusr}@localhost IDENTIFIED BY '${mysqlpass}';"
                Q3="GRANT ALL PRIVILEGES ON ${dbusrentry}.* TO ${mysqlusr}@localhost;"
                Q4="FLUSH PRIVILEGES;"
                SQL="${Q1}${Q2}${Q3}${Q4}"

                $MYSQL -u$mysqlusr -p$mysqlpass -e "$SQL"

                wp core download --locale=en_US --force
                wp config create --dbname=$dbusrentry --dbuser=$mysqlusr --dbpass=$mysqlpass --dbhost=localhost --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', false );
PHP
                wp db drop --yes
                wp db create
            else
                exit
            fi
        fi
        # Wordpess is installing...
        wp core install --url=$ans --title=$ans --admin_user="admin" --admin_password="123456" --admin_email="admin@${ans}" --skip-email
        # User installs plugins
        echo -e "${green}Please enter any plugins you want to install from wordpress.org, separated by comma and no spaces \n ex: contact-form-7,wordpress-seo,clesraw3-total-cache \n (You can find the name of the plugin as slug in the url of the plugin home page \n ex: https://wordpress.org/plugins/${blue}w3-total-cache${reset}). \n ${red}Press enter if you don't want to install plugins${reset} "
        read plugins
        if [ "$plugins" != "" ]; then
            OIFS=$IFS
            IFS=','
            arr=($plugins)
            for i in "${!arr[@]}"; do wp plugin install ${arr[$i]} --activate; done
            unset IFS
        fi

        wp rewrite flush --hard
        #We create the .htaccess cause WP dosn't have permissions on the local server
        bash -c 'cat << EOF > .htaccess
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
EOF'
        else
            echo "Have a nice day, amigo!"
        exit
    fi

    echo -e "${green}You can visit your Wordpress admin panel at ${ans}/wp-admin, \n ${red}user name: admin, password: 123456${reset}"
    exit
elif [ ${machine} == "CYGWIN" ]
then
   echo "We don't support CYGWIN yet!"
else
   echo "We don't support your macchine yet!"
fi


exit
