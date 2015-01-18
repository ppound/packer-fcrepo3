#! /bin/bash

source /etc/profile.d/tomcat.sh

# Install GSearch
if hash wget 2>/dev/null; then
  echo "Downloading the GSearch war file from Sourceforge..."

  wget -q -O /tmp/gsearch.zip \
      $SOURCEFORGE/fedora-commons/services/$FEDORA_SERVICES_VERSION/fedoragsearch-$GSEARCH_VERSION.zip
else
  echo "The wget application doesn't seem to be installed; it needs to be to proceed with the installation"
  exit 1
fi

# Check that downloaded file exists and that it's not a zero length file
if [ ! -f /tmp/gsearch.zip ] || [ ! -s /tmp/gsearch.zip ]; then
  echo "Doesn't seem like the GSearch zip file was successfully downloaded from Sourceforge"
  exit 1
else
  echo "Download successful!"
fi

unzip -d /tmp /tmp/gsearch.zip
cd /tmp/fedoragsearch-$GSEARCH_VERSION
sudo mv fedoragsearch.war $CATALINA_HOME/webapps
unzip -d $CATALINA_HOME/webapps $CATALINA_HOME/webapps/fedoragsearch.war

# TODO: Configure GSearch