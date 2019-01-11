################################################################################
# DO NOT EDIT THIS SCRIPT! Go to scripts/install_settings.sh                   #
################################################################################
if [ $(cat scripts/install_settings.sh | grep -E "([ \t]+=[ \t]?|[ \t]?=[ \t]+)" | wc -l) -ne 0 ]; then
     echo "scripts/install_settings.sh contains an invalid configuration line: "$(cat scripts/install_settings.sh | grep -E "([ \t]+=[ \t]?|[ \t]?=[ \t]+)")
     exit 1
fi
source scripts/install_settings.sh

# Ensure the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# For setting up collection interface (ex: eth0)
#COLLECTION_INTERFACE=<>
echo "Interface List:"
ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
echo ""
read -p "Collection Interface? " COLLECTION_INTERFACE
export COLLECTION_INTERFACE
# For setting up the interface analysts talk to (ex: eth0)
#ANALYST_INTERFACE=<>
echo ""
echo "Interface List:"
ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
echo ""
read -p "Analysis Interface? " ANALYST_INTERFACE
export ANALYST_INTERFACE
# The name of the domain (ex: example.com)
#DOMAIN=<>
#read -p "Domain? " DOMAIN
# Check to see if the server is correctly named and skip the DOMAIN assignment
# if it is. Otherwise, prompt the user for a domain name.
if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi
export DOMAIN
# Default IPA Administrator Username
read -p "Admin Name (no spaces)? " IPA_USERNAME
export IPA_USERNAME
# Default IPA Administrator password.
#IPA_ADMIN_PASSWORD=<>
read -p "Admin Password? " IPA_ADMIN_PASSWORD
export IPA_ADMIN_PASSWORD
# Grab the IP from the analyst interface. This prevents users from incorrectly
# inputting the first 3 octets.
# Format Example: 192.168.1
export IP=$(ip addr | grep -e 'inet ' | grep -e ".*$ANALYST_INTERFACE$" | awk \
    '{print $2}' | cut -f1 -d '/' | awk -F . '{print $1"."$2"."$3}')
# The IP schema of the server and its applications.
export SENSOR_IP=$IP$SENSOR_IP
export DATA_IP=$IP$DATA_IP
export APP_IP=$IP$APP_IP
export IPA_IP=$IP$IPA_IP
export ES_IP=$IP$ES_IP
export ESSEARCH_IP=$IP$ESSEARCH_IP
export KIBANA_IP=$IP$KIBANA_IP
export OWNCLOUD_IP=$IP$OWNCLOUD_IP
export GOGS_IP=$IP$GOGS_IP
export CHAT_IP=$IP$CHAT_IP
export SPLUNK_IP=$IP$SPLUNK_IP
export HIVE_IP=$IP$HIVE_IP
export CORTEX_IP=$IP$CORTEX_IP
export ESDATA_IP=$IP$ESDATA_IP

################################################################################
# CONFIGURATION SCRIPT --- EDIT BELOW AT YOUR OWN RISK                         #
################################################################################

bash scripts/setup_networking.sh
if $LOCAL_REPO; then
    bash scripts/preinstall_rpms.sh
else
    bash scripts/rpm_install.sh
fi
if $IS_APP_SERVER; then
    bash scripts/application_install.sh
fi
if $IS_DATASTORE; then
    bash scripts/datastore_install.sh
fi
if $IS_SENSOR; then
    bash scripts/sensor_install.sh
fi
bash scripts/configure_first_user.sh
