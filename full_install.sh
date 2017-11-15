################################################################################
# Configure Variables below to your hardware settings.                         #
################################################################################
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
IP=$(ip addr | grep -e 'inet ' | grep -e ".*$ANALYST_INTERFACE$" | awk \
    '{print $2}' | cut -f1 -d '/' | awk -F . '{print $1"."$2"."$3}')
# The IP schema of the server and its applications.
export IPA_IP=$IP.5
export ES_IP=$IP.6
export ESSEARCH_IP=$IP.7
export KIBANA_IP=$IP.8
export OWNCLOUD_IP=$IP.9
export GOGS_IP=$IP.10
export CHAT_IP=$IP.11
export SPLUNK_IP=$IP.12
export HIVE_IP=$IP.13
export CORTEX_IP=$IP.14
export ESDATA_IP=$IP.15
# Number of Bro workers to process traffic.
# 4 workers per 1 Gbps of traffic.
export BRO_WORKERS=4      # For VMs
# Heap Space Allocation for Elasticsearch (do NOT use over 31g)
export ES_RAM=2g     # 2GiB Heap Space for Elasticsearch (For VMs)
# How many ElasticSearch Data nodes do you want? (Remember: there is 1 Master
# and 1 Search Node, already.)
export ES_DATA_NODES=2
# For disabling the stenographer install - because it takes up a lot of
# resources unnecessarily, for testing.
export NABLE_STENOGRAPHER=true
export ENABLE_ELK=true
export ENABLE_SPLUNK=true
export ENABLE_GOGS=true
export ENABLE_CHAT=true
export ENABLE_HIVE=true
export ENABLE_OWNCLOUD=true
export ENABLE_SURICATA=true
export ENABLE_BRO=true
# Number of stenographer collection threads.
# 1 thread per 1 Gbps of traffic, minimum 2 threads.
export STENO_THREADS=2

################################################################################
# CONFIGURATION SCRIPT --- EDIT BELOW AT YOUR OWN RISK                         #
################################################################################
# Firewalld is currently broken with docker. Until the issue is fixed, it must
# be turned off.
systemctl disable firewalld
systemctl stop firewalld

# Disable the local GPG requirement (DISA STIG)
# Enabled at the end of the script.
sed -e "s/repo_gpgcheck=1/repo_gpgcheck=0/g" -e "s/localpkg_gpgcheck=1/localpkg_gpgcheck=0/g" -i /etc/yum.conf
yum clean all

# Ensure FreeIPA is the default DNS server.
if grep -q DNS1 /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE; then
   sed -e "s@DNS1=\\"?.*\\"?@DNS1=\"$IPA_IP\"@g" -i /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
else
    echo -e "\nDNS1=\"$IPA_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$ANALYST_INTERFACE
fi
systemctl restart network

# Locally installs required RPMs for every application.
mkdir /tmp/backup
mv /etc/yum.repos.d/* /tmp/backup
yum -y localinstall rpm/updates/*.rpm
yum -y localinstall rpm/extras/*.rpm
if ! (rpm -qa | grep docker 2>&1 > /dev/null); then
    yum -y localinstall rpm/docker/*.rpm
fi
if ! (rpm -qa | grep ipa-client 2>&1 > /dev/null); then
    yum -y localinstall rpm/ipa-client/*.rpm
fi
if ! (rpm -qa | grep filebeat 2>&1 > /dev/null); then
    yum -y localinstall rpm/filebeat/*.rpm
fi
if ! (rpm -qa | grep bro 2>&1 > /dev/null); then
    yum -y localinstall rpm/bro/*.rpm
fi
if ! (rpm -qa | grep suricata 2>&1 > /dev/null); then
    yum -y localinstall rpm/suricata/*.rpm
fi
if ! (rpm -qa | grep stenographer 2>&1 > /dev/null); then
    yum -y localinstall rpm/stenographer/*.rpm
fi
mv /tmp/backup/* /etc/yum.repos.d
# Points the server to its proper DNS server (FreeIPA).
echo -e "\nnameserver $IPA_IP\n" >> /etc/resolv.conf

# Allow IPA admins to sudo.
echo -e "%admins ALL=(ALL)\tALL\n" >> /etc/sudoers

################################################################################

bash scripts/application_install.sh
bash scripts/datastore_install.sh
bash scripts/sensor_install.sh

################################################################################
# CONFIGURE: First User/Admin                                                  #
################################################################################
# Create new admin's home directory
if ! [[ -d /home/$IPA_USERNAME ]]; then
    cp -R /etc/skel /home
    mv /home/skel /home/$IPA_USERNAME
fi

# Configure IPA client -- Nothing bad happens if this is tried twice, so I won't check to see if it's setup.
ipa-client-install -U --server=ipa.$DOMAIN \
                    --domain=$DOMAIN \
                    -p admin \
                    -w $IPA_ADMIN_PASSWORD \
                    --mkhomedir \
                    --hostname server.$DOMAIN \
                    --ntp-server=ipa.$DOMAIN

# Remove root access
sed -e 's/^#PermitRootLogin yes$/PermitRootLogin no/g' -i /etc/ssh/sshd_config
sed -e 's@^\(root.*\)/bin/bash$@\1/sbin/nologin@g' -i /etc/passwd

# Configure Firewall
#firewall-cmd --zone=public --add-port={22/tcp,80/tcp,53/udp,53/tcp,443/tcp,389/tcp,636/tcp,88/tcp,464/tcp,88/udp,464/udp,123/udp,7389/tcp,9443/tcp,9444/tcp,9445/tcp,5044/tcp,9600/tcp,9200/tcp,9300/tcp,1022/tcp,27017/tcp,9997/tcp,8088/tcp,1514/tcp} --permanent
#firewall-cmd --permanent --zone=trusted --change-interface=docker0
#firewall-cmd --zone=public --permanent --add-masquerade
#firewall-cmd --reload

sed -e "s/repo_gpgcheck=0/repo_gpgcheck=1/g" -e "s/localpkg_gpgcheck=0/localpkg_gpgcheck=1/g" -i /etc/yum.conf
yum clean all
