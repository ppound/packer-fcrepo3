#! /bin/bash

source /etc/profile.d/tomcat.sh

# Adjust a localhost setting to work when the server is a non-Docker instance
sudo cp /tmp/reconfigure-fedora.sh /usr/local/sbin/reconfigure-fedora.sh
sudo chown root:root /usr/local/sbin/reconfigure-fedora.sh
sudo chmod 700 /usr/local/sbin/reconfigure-fedora.sh
sudo sed -i -e "s|  start)|  start)\n\t/usr/local/sbin/reconfigure-fedora.sh start|" /etc/init.d/$CATALINA_VERSION
sudo sed -i -e "s|  stop)|  stop)\n\t/usr/local/sbin/reconfigure-fedora.sh stop|" /etc/init.d/$CATALINA_VERSION