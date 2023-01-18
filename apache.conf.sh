#!/bin/bash

#
# Automate The Installation and configuration of Apache webserver on ubuntu
# Author: Onuwa Chinedu

#######################################
# Print a message in a given color.
# Arguments:
#   Color. eg: green, red
#######################################
function print_color(){
  NC='\033[0m' # No Color

  case $1 in
    "green") COLOR='\033[0;32m' ;;
    "red") COLOR='\033[0;31m' ;;
    "*") COLOR='\033[0m' ;;
  esac

  echo -e "\n\n${COLOR} $2 ${NC}"
}

#######################################
# Prompt the user to enter Variables for configuration
# Arguments:
#   Variables. eg: ServerName, Document_Root
#######################################
function enter_variables(){
  read -p "Enter the Root Directory you wish to create your site eg(/var/www/myapp/html): " Document_Root
  read -p "Enter the name you wish to name your site: " Site_Name
}

#######################################
# Check the status of a given service. If not active exit script
# Arguments:
#   Service Name. eg: firewalld, mariadb
#######################################
function check_service_status(){
  service_is_active=$(sudo systemctl is-active $1)

  if [ $service_is_active = "active" ]
  then
    echo "$1 is active and running"
  else
    echo "$1 is not active/running"
    exit 1
  fi
}

#######################################
# Check the status of a firewalld rule. If not configured exit.
# Arguments:
#   Port Number. eg: 3306, 80
#######################################
function is_firewalld_rule_configured(){

  firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports)

  if [[ $firewalld_ports == *$1* ]]
  then
    echo "FirewallD has port $1 configured"
  else
    echo "FirewallD port $1 is not configured"
    exit 1
  fi
}

if (( $EUID != 0 )); 
  then
    echo "Please run this file as a root user(Use sudo)"
    exit
else

    enter_variables
    # Running updates on the system
    print_color "green" "getting updates"
    sudo apt update

    print_color "green" "Checking and upgrading the system ..."
    sudo apt -y upgrade


    # Installing Apache Webserver
    print_color "green" "Installing Apache Web-server ..."
    sudo apt install -y apache2
    sudo systemctl enable apache2
    check_service_status apache2


    # Installing Firewalld
    print_color "green" "Installing the firewalld ..."
    sudo apt install -y firewalld
    sudo systemctl enable firewalld

    # Check if the status of firewalld is active
    check_service_status firewalld

    # Configuring firewall rule for the apache webserver
    print_color "green" "Configuring port 80 for apache"
    sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
    sudo firewall-cmd --reload

    is_firewalld_rule_configured 80

    # Create a Directory for your Web Server {Dont use the default document root}
    sudo mkdir -p $Document_Root
    print_color "green" "Created directory $Document_Root"
    # Change the ownership of the directory above
    sudo chown -R $USER:$USER $Document_Root
    sudo chmod -R 755 $Document_Root
    print_color "green" "Changed The file Owner of the $Document_Root directory"

    # Create your Index.html file
    sudo cat > ${Document_Root}/index.html <<-EOF
    <html>
    <head>
    <title>Welcome to info.net!</title>
    </head>
    <body>
    <h1>You are running info.net on Ubuntu 20.04!</h1>
    </body>
    </html>
EOF

    # Create a virtual host file
    sudo cat > /etc/apache2/sites-available/${Site_Name}.conf <<-EOF
    <VirtualHost *:80>
    ServerAdmin admin@${Site_Name}
    ServerName ${Site_Name}
    ServerAlias ${Site_Name}
    DocumentRoot ${Document_Root}
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    </VirtualHost>
EOF

    # Activate the virtual host configuration file
    sudo cat > /etc/apache2/conf-available/servername.conf <<-EOF
    ServerName ${Site_Name}

EOF

    sudo cat >> /etc/hosts <<-EOF
    127.0.0.1       ${Site_Name}
EOF

    sudo a2enconf servername

    sudo a2ensite ${Site_Name}.conf

    # Disable the default configuration file
    sudo a2dissite 000-default.conf
    print_color "green" "000-default.conf disabled"
    # Restart Apache2
    sudo systemctl restart apache2
    print_color "green"  "apache2 Restarted"
    # Test for errors
    sudo apache2ctl configtest

    fi
