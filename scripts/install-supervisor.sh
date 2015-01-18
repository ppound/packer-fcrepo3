#! /bin/bash

# Install Supervisor
sudo apt-get install -y supervisor

# Install Supervisor's configuration file
sudo tee /etc/supervisor/supervisord.conf > /dev/null <<'SUPERVISOR_CONFIG_EOF'

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[supervisord]
#user=ubuntu
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor

[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[include]
files=/etc/supervisor/conf.d/*.conf

[program:tomcat]
user=tomcat7
command=authbind --deep /usr/share/tomcat7/bin/catalina.sh run
autostart=true
autorestart=true
environment=CATALINA_BASE="/var/lib/tomcat7", CATALINA_HOME="/usr/share/tomcat7", CATALINA_TMPDIR="/tmp"

[program:mysqld]
user=root
command=/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/bin/mysqld_safe --pid-file=/var/run/mysqld/mysqld.pid
autostart=true
autorestart=true

SUPERVISOR_CONFIG_EOF
