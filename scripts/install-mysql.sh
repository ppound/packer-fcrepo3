#! /bin/dash

# Install MySQL non-interactively by using debconf-utils to set the MySQL installation variables
sudo apt-get install -y debconf-utils

# We use Ubuntu's default shell, Dash, for script this since it doesn't keep command line history
echo mysql-server mysql-server/root_password password $ROOT_DB_PASSWORD | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $ROOT_DB_PASSWORD | sudo debconf-set-selections
  
sudo apt-get install -y mysql-server mysql-client