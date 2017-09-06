#!/bin/bash

#TODO remove this
#nukes test account if it exists
/scripts/removeacct --force dev >/dev/null 2>&1

rand() { cat /dev/urandom | tr -dc 'A-z0-9' | head -c30 ; echo; }

# get details
read -p "What is the source domain? " domain;
user=$(/scripts/whoowns ${domain});
docroot="$(grep -e ^${domain}: /etc/userdatadomains | awk -F'==' '{print $5}')/";
dbname=$(grep DB_NAME ${docroot}/wp-config.php | cut -d\' -f4);
dbuser=$(grep DB_USER ${docroot}/wp-config.php | cut -d\' -f4);
dbpass=$(grep DB_PASS ${docroot}/wp-config.php | cut -d\' -f4);
prefix=$(grep ^\$table_prefix ${docroot}/wp-config.php | cut -d\' -f2);
siteurl=$(mysql -Nse "select option_value from ${dbname}.${prefix}options where option_name='siteurl'");
home=$(mysql -Nse "select option_value from ${dbname}.${prefix}options where option_name='home'");

echo -e "cPanel username: ${user}\nDocument root: ${docroot}\nDatabase name: ${dbname}\nTable prefix: ${prefix}\nSiteurl: ${siteurl}\nHome: ${home}";
echo

# backup existing
echo -e "Creating Backup"
#/scripts/pkgacct $user

# create new account
read -p "What is the new domain? " new_domain
read -p "New cPanel username? " new_user
read -p "New cPanel password? (random) " new_pass

if [ -z $new_pass ]; then
	new_pass=$(rand)
fi

old_dbname=$(echo $dbname | cut -d_ -f2)
old_dbuser=$(echo $dbuser | cut -d_ -f2)
new_dbname="$(echo $new_user | head -c8)_$old_dbname"
new_dbuser="$(echo $new_user | head -c8)_$old_dbuser"

/scripts/createacct $new_domain $new_user $new_pass

new_docroot="/home/$new_user/public_html"
new_dbpass=$(rand)

uapi --user=$new_user Mysql create_database name=$new_dbname
uapi --user=$new_user Mysql create_user name=$new_dbuser password=$new_dbpass
uapi --user=$new_user Mysql set_privileges_on_database database=$new_dbname user=$new_dbuser privileges="ALL PRIVILEGES"

# copy data

rsync -avHP $docroot $new_docroot
chown -R ${new_user}: $new_docroot
chgrp nobody $new_docroot

mysqldump $dbname | mysql $new_dbname

echo "Replacing wp-config.php"
cp -a $new_docroot/wp-config.php{,.bak}
sed -i "s/$dbname/$new_dbname/g" $new_docroot/wp-config.php
sed -i "s/$dbpass/$new_dbpass/g" $new_docroot/wp-config.php

#update siteurl and home
echo "update ${new_dbname}.${prefix}options set option_value = replace(option_value, '${domain}', '${new_domain}')"
mysql -Nse "update ${new_dbname}.${prefix}options set option_value = replace(option_value, '${domain}', '${new_domain}')";




