#! /bin/bash

# This is a hacky utility script that makes the Fedora server adjust to its current environment when deployed with
# a 'localhost' server_host_name. It's useful when deployed to AWS without an elastic IP (where the IP changes).

source /etc/profile.d/fedora.sh
source /etc/profile.d/tomcat.sh
APP_CONTEXT_FILE="$CATALINA_HOME/webapps/fedora/WEB-INF/applicationContext.xml"

# Check whether what we have is a valid IPv4 address [TODO: Support IPv6]
function is-valid-ip() {
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi

  return $stat
}

# Try to get an IP to add as host name but if we can't just leave the value as 'localhost'
function add-ip-host-name {
  SERVER_HOST=`cut -d "=" -f 2 <<< $(grep "fedora.serverHost" $FEDORA_HOME/install/install.properties)`
  if [ `is-valid-ip $SERVER_HOST` ] || [ "$SERVER_HOST" == "localhost" ]; then
    # Check to see if we're running from AWS
    SERVER_IP=`wget -t 5 -T 5 -q -O - http://instance-data/latest/meta-data/public-ipv4`

    # If we're not on AWS, check a different way
    if [ ! -z "$SERVER_IP" ]; then
      SERVER_IP=`wget -t 5 -T 5 -q -O - http://lisforge.net/ip.php`
    fi

    if [ ! -z "$SERVER_IP" ]; then
      sudo sed -i -e "s|localhost|$SERVER_IP|" $APP_CONTEXT_FILE
      sudo sed -i -e "s|=localhost$|=$SERVER_IP|" $FEDORA_HOME/install/install.properties
      grep -rl $FEDORA_HOME -e "http\:\/\/localhost" | xargs sudo sed -i "s|http\://localhost|http\://$SERVER_IP|g"
      grep -rl $CATALINA_HOME -e "http\:\/\/localhost" | xargs sudo sed -i "s|http\://localhost|http\://$SERVER_IP|g"
    fi
  fi
}

function remove-ip-host-name {
  SERVER_HOST=`cut -d "=" -f 2 <<< $(grep "fedora.serverHost" $FEDORA_HOME/install/install.properties)`
  if is-valid-ip $SERVER_HOST; then
    sudo sed -i -e "s|$SERVER_HOST|localhost|" $APP_CONTEXT_FILE
    sudo sed -i -e "s|^fedora.serverHost=.*$|fedora.serverHost=localhost|" $FEDORA_HOME/install/install.properties
    grep -rl $FEDORA_HOME -e "http\:\/\/$SERVER_HOST" | xargs sudo sed -i "s|http\://$SERVER_HOST|http\://localhost|g"
    grep -rl $CATALINA_HOME -e "http\:\/\/$SERVER_HOST" | xargs sudo sed -i "s|http\://$SERVER_HOST|http\://localhost|g"
  fi
}

if [ ! -z "$1" ]; then
  if [ "$1" == "start" ]; then
    add-ip-host-name
  elif [ "$1" == "stop" ]; then
    remove-ip-host-name
  fi
fi
