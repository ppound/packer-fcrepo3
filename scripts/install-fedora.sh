#! /bin/bash

# Install fcrepo3 dependencies that haven't already been installed by other scripts
sudo apt-get install -y libmysql-java unzip

# Set FEDORA_HOME and add 'bin' directories to the system PATH
FEDORA_BINS="\$FEDORA_HOME/server/bin:\$FEDORA_HOME/client/bin"
echo "export FEDORA_HOME=/opt/fedora" | sudo tee -a /etc/profile.d/fedora.sh > /dev/null
echo "export PATH=\$PATH:$FEDORA_BINS" | sudo tee -a /etc/profile.d/fedora.sh > /dev/null

# Set up the Fedora database in the MySQL that's already been installed by another script
# For Fedora, MySQL is pretty much just a cache; this is why we put it on the same machine
if hash mysql 2>/dev/null; then
  MYSQL_PID_FILE="/var/run/mysqld/mysqld.pid"

  # If MySQL is not already running, start it so we can configure the Fedora database user
  if [[ -z $(pidof mysqld) ]]; then
    sudo /usr/bin/mysqld_safe --pid-file="$MYSQL_PID_FILE" &
    sleep 5

    if [ -f "$MYSQL_PID_FILE" ]; then
      MYSQL_PID=$(cat $MYSQL_PID_FILE)
    else
      echo "Cannot start the MySQL server; something is wrong!"
      exit 1
    fi
  fi

  # Install Fedora database user
  mysql -u root -p$ROOT_DB_PASSWORD -e 'CREATE DATABASE fedora;'
  mysql -u root -p$ROOT_DB_PASSWORD -e \
    "GRANT ALL PRIVILEGES ON fedora.* TO 'fedoraDbUser'@'localhost' IDENTIFIED BY \"$FEDORA_DB_PASSWORD\";"
  mysql -u root -p$ROOT_DB_PASSWORD -e \
    "GRANT ALL PRIVILEGES ON fedora.* TO 'fedoraDbUser'@'%' IDENTIFIED BY \"$FEDORA_DB_PASSWORD\";"
  mysql -u root -p$ROOT_DB_PASSWORD -e "FLUSH PRIVILEGES;"

  # We're done with it, go ahead and shutdown the database again
  if [[ ! -z $MYSQL_PID ]]; then
    sudo kill $MYSQL_PID
  fi
else
  echo "The MySQL client doesn't seem to be installed; it needs to be to proceed with the Fedora installation"
  exit 1
fi

# Install Fedora using our custom installation configuration
if hash wget 2>/dev/null; then
  echo "Downloading the Fedora installation jar file from Sourceforge..."

  wget -q -O /tmp/fedora.jar \
      $SOURCEFORGE/fedora-commons/fedora/${FEDORA_VERSION}/fcrepo-installer-${FEDORA_VERSION}.jar
else
  echo "The wget application doesn't seem to be installed; it needs to be to proceed with the installation"
  exit 1
fi

# Check that downloaded file exists and that it's not a zero length file
if [ ! -f /tmp/fedora.jar ] || [ ! -s /tmp/fedora.jar ]; then
  echo "Doesn't seem like the Fedora jar file was successfully downloaded from Sourceforge"
  exit 1
else
  echo "Download successful!"
fi

# Let's swap in the values for the variables in the fedora-install.properties file
source /etc/profile.d/fedora.sh
source /etc/profile.d/tomcat.sh
while read LINE; do eval echo "$LINE"; done < /tmp/fedora-install.properties > /tmp/fedora-install-filtered.properties

# Start the installation of Fedora
sudo -E bash -c "java -jar /tmp/fedora.jar /tmp/fedora-install-filtered.properties"
sudo rm /tmp/fedora-install-filtered.properties

# Check to see if the installation script completed successfully
if [ ! -d "$FEDORA_HOME" ]; then
  echo "Fedora was not installed correctly; $FEDORA_HOME does not exist"
  exit 1
fi

sudo chown -R $CATALINA_USER:$CATALINA_USER $FEDORA_HOME

# Remove the Fedora Demo webapp before we deploy Tomcat
sudo rm $CATALINA_HOME/webapps/fedora-demo.war

# Go ahead and unpack the webapps so we can tweak some of their files
sudo unzip -d $CATALINA_HOME/webapps/fedora $CATALINA_HOME/webapps/fedora.war
sudo unzip -d $CATALINA_HOME/webapps/fop $CATALINA_HOME/webapps/fop.war
sudo unzip -d $CATALINA_HOME/webapps/imagemanip $CATALINA_HOME/webapps/imagemanip.war
sudo unzip -d $CATALINA_HOME/webapps/saxon $CATALINA_HOME/webapps/saxon.war

# Give the Tomcat user ownership of the unpacked webapps
sudo chown -R $CATALINA_USER:$CATALINA_USER $CATALINA_HOME/webapps

# Tweak the webapp's config so we can set the fedora.home variable to FEDORA_HOME
sudo sed -i -e "s/\/tmp\/fcrepo<\/param-value>/\${FEDORA_HOME}<\/param-value>/g" \
    $CATALINA_HOME/webapps/fedora/WEB-INF/web.xml

# Turn off Tomcat's pre-configured console handler, which isn't log rotated; we'll use the file handlers, which are
AVAILABLE_HANDLERS="handlers = 1catalina.org.apache.juli.FileHandler, 2localhost.org.apache.juli.FileHandler"
CONFIGURED_HANDLERS=".handlers = 1catalina.org.apache.juli.FileHandler"
sudo sed -i -e "s/^handlers.*$/$AVAILABLE_HANDLERS/" $CATALINA_CONFIGS/logging.properties
sudo sed -i -e "s/^\.handlers.*$/$CONFIGURED_HANDLERS/" $CATALINA_CONFIGS/logging.properties
sudo sed -i -e "s/^java\.util\.logging\.ConsoleHandler\.level.*$//" $CATALINA_CONFIGS/logging.properties

# Configure the Fedora OAI-PMH server
APP_CONTEXT_FILE="$CATALINA_HOME/webapps/fedora/WEB-INF/applicationContext.xml"
FEDORA_FCFG_FILE="$FEDORA_HOME/server/config/fedora.fcfg"
sudo sed -i -e "s/bob\@example.org sally\@example.org/$SERVER_ADMIN_EMAIL/" $APP_CONTEXT_FILE
sudo sed -i -e "s/Your Fedora Repository Name Here/$FEDORA_REPOSITORY_NAME/" $FEDORA_FCFG_FILE
sudo sed -i -e "s/oai-admin\@example.org bob\@example.org/$SERVER_ADMIN_EMAIL/" $FEDORA_FCFG_FILE
sudo sed -i -e "s/example\.org/$SERVER_HOST_NAME/" $FEDORA_FCFG_FILE
sudo sed -i -e "s/changeme/$FEDORA_PID_NAMESPACE/" $FEDORA_FCFG_FILE

# We may have chosen a different port from 8080 so let's clean up references to 8080
grep -rl $CATALINA_HOME/webapps -e "8080" | xargs sudo sed -i "s/8080/$TOMCAT_PORT/g"
grep -rl $CATALINA_HOME/webapps -e "8443" | xargs sudo sed -i "s/8443/$TOMCAT_SSH_PORT/g"
grep -rl $FEDORA_HOME -e "8080" | xargs sudo sed -i "s/8080/$TOMCAT_PORT/g"
grep -rl $FEDORA_HOME -e "8443" | xargs sudo sed -i "s/8443/$TOMCAT_SSH_PORT/g"

# Add a default landing page that redirects to the Fedora webapp
sudo tee $CATALINA_HOME/webapps/ROOT/index.html > /dev/null <<INDEX_EOF

<!DOCTYPE html>
<html>
  <head>
    <title>Fedora Commons Repository Server ($FEDORA_VERSION)</title>
    <meta http-equiv="refresh" content="0;url=/fedora"/>
  </head>
  <body>
    <p>Please access the Fedora Commons Repository at <a href="/fedora">/fedora</a>.</p>
  </body>
</html>

INDEX_EOF