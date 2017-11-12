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
# For setting up the interface analysts talk to (ex: eth0)
#ANALYST_INTERFACE=<>
echo ""
echo "Interface List:"
ip addr | grep -e ^[0-9] | awk -F ' '  '{print $2}' | cut -d ':' -f1
echo ""
read -p "Analysis Interface? " ANALYST_INTERFACE
# The name of the domain (ex: example.com)
#DOMAIN=<>
#read -p "Domain? " DOMAIN
# Check to see if the server is correctly named and skip the DOMAIN assignment
# if it is. Otherwise, prompt the user for a domain name.
if (($(hostname | grep -o "\." | wc -l) > 1)); then DOMAIN=$(echo `hostname` | sed 's/^[^\.]*\.//g'); else read -p "Domain? " DOMAIN; fi
# Default IPA Administrator Username
read -p "Admin Name (no spaces)? " IPA_USERNAME
# Default IPA Administrator password.
#IPA_ADMIN_PASSWORD=<>
read -p "Admin Password? " IPA_ADMIN_PASSWORD
################################################################################
# ADVANCED CONFIGURATION --- EDIT BELOW FOR ADVANCED USERS                     #
################################################################################
# Number of Bro workers to process traffic.
# 4 workers per 1 Gbps of traffic.
BRO_WORKERS=4      # For VMs
# Heap Space Allocation for Elasticsearch (do NOT use over 31g)
ES_RAM=2g     # 2GiB Heap Space for Elasticsearch (For VMs)
# How many ElasticSearch Data nodes do you want? (Remember: there is 1 Master
# and 1 Search Node, already.)
ES_DATA_NODES=2
# For disabling the stenographer install - because it takes up a lot of
# resources unnecessarily, for testing.
ENABLE_STENOGRAPHER=true
ENABLE_ELK=true
ENABLE_SPLUNK=true
ENABLE_TOOLS=true
ENABLE_SURICATA=true
ENABLE_BRO=true
# Number of stenographer collection threads.
# 1 thread per 1 Gbps of traffic, minimum 2 threads.
STENO_THREADS=2
# Grab the IP from the analyst interface. This prevents users from incorrectly
# inputting the first 3 octets.
# Format Example: 192.168.1
IP=$(ip addr | grep -e 'inet ' | grep -e ".*$ANALYST_INTERFACE$" | awk \
    '{print $2}' | cut -f1 -d '/' | awk -F . '{print $1"."$2"."$3}')
# The IP schema of the server and its applications.
IPA_IP=$IP.5
ES_IP=$IP.6
ESSEARCH_IP=$IP.7
KIBANA_IP=$IP.8
OWNCLOUD_IP=$IP.9
GOGS_IP=$IP.10
CHAT_IP=$IP.11
SPLUNK_IP=$IP.12
HIVE_IP=$IP.13
CORTEX_IP=$IP.14
ESDATA_IP=$IP.15

IPCOUNTER=0
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
yum -y localinstall rpm/ipa-client/*.rpm
yum -y localinstall rpm/filebeat/*.rpm
yum -y localinstall rpm/bro/*.rpm
yum -y localinstall rpm/suricata/*.rpm
yum -y localinstall rpm/stenographer/*.rpm
mv /tmp/backup/* /etc/yum.repos.d
# Points the server to its proper DNS server (FreeIPA).
echo -e "\nnameserver $IPA_IP\n" >> /etc/resolv.conf

# Allow IPA admins to sudo.
echo -e "%admins ALL=(ALL)\tALL\n" >> /etc/sudoers

#------------------------------------------------------------------------------#
# Beginning: Sensor Configuration                                              #
#------------------------------------------------------------------------------#

# Creating directories ahead of install for scripted ELK configuration.
mkdir -p /data/bro/current
mkdir -p /data/bro/spool

# Create CozyStack installed event.
echo "{\"ts\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"source\":\"Install Script\", \"message\": \"CozyStack installed. This is needed for ELK to initialize correctly.\"}" > /data/bro/current/cozy.log

################################################################################
# INSTALL: Bro NSM                                                             #
################################################################################
if $ENABLE_BRO; then
    BRO_DIR=/opt
    # Configure Bro to run in clustered mode.
    cp bro/etc/node.cfg $BRO_DIR/bro/etc/node.cfg
    # Configure the number of nodes for Bro.
    COUNTER=2
    while [ $COUNTER -le $BRO_WORKERS ]; do
      echo [worker-$COUNTER] >> $BRO_DIR/bro/etc/node.cfg
      echo type=worker >> $BRO_DIR/bro/etc/node.cfg
      echo host=localhost >> $BRO_DIR/bro/etc/node.cfg
      echo interface=af_packet::$COLLECTION_INTERFACE >> $BRO_DIR/bro/etc/node.cfg
      let COUNTER=COUNTER+1
    done
    # Configure the interface to listen on.
    sed -e "s/INTERFACE/$COLLECTION_INTERFACE/g" -i $BRO_DIR/bro/etc/node.cfg
    # Configure the BroCTL to have a temporary in-place sensor setup.
    cp bro/etc/broctl.cfg $BRO_DIR/bro/etc/broctl.cfg
    # Disable certain logs and output in JSON.
    cp bro/etc/local.bro $BRO_DIR/bro/share/bro/site/local.bro
################################################################################
# DEPLOY: Bro NSM                                                              #
################################################################################
    ln -s $BRO_DIR/bro/bin/bro /usr/bin/bro
    ln -s $BRO_DIR/bro/bin/broctl /usr/bin/broctl
    $BRO_DIR/bro/bin/broctl install
    $BRO_DIR/bro/bin/broctl deploy
    $BRO_DIR/bro/bin/broctl stop
    cp bro/etc/bro.service /etc/systemd/system
    systemctl enable bro
    systemctl start bro
fi
################################################################################
# INSTALL: Suricata IDS                                                        #
################################################################################
if $ENABLE_SURICATA; then
    cp suricata/etc/suricata.yaml /etc/suricata/suricata.yaml
    sed -e "s/DEVICENAME/$COLLECTION_INTERFACE/g" -i /etc/suricata/suricata.yaml
    ethtool -K $COLLECTION_INTERFACE lro off
    ethtool -K $COLLECTION_INTERFACE gro off
    ldconfig /usr/local/lib
    cp suricata/suricata.service /etc/systemd/system
    sed -e "s/INTERFACE/$COLLECTION_INTERFACE/g" \
        -i /etc/systemd/system/suricata.service
    systemctl enable suricata
    systemctl start suricata
################################################################################
# CONFIGURE: Suricata Rules                                                    #
################################################################################
    mkdir /etc/suricata/rules
    cp suricata/rules/emerging-all.rules /etc/suricata/rules
fi

################################################################################
# INSTALL: Google Stenographer                                                 #
################################################################################
if $ENABLE_STENOGRAPHER; then
    let STENO_THREADS=STENO_THREADS-1
    COUNTER=0
    while [ $COUNTER -le $STENO_THREADS ]; do
        mkdir -p /data/index/$COUNTER
        chown stenographer:stenographer /data/index/$COUNTER
        mkdir -p /data/packets/$COUNTER
        chown stenographer:stenographer /data/packets/$COUNTER

        PDIR="\"PacketsDirectory\"\: \"\/data\/packets\/$COUNTER\""
        IDIR="\"IndexDirectory\"\: \"\/data\/index\/$COUNTER\""
        LINE="\n\t$PDIR\,\n\t$IDIR\n\t"

        if [ $COUNTER -eq $STENO_THREADS ]; then
            sed -e "s/THREADHOLDER/\t\{$LINE\}/g" \
                -i stenographer/config
        else
            sed -e "s/THREADHOLDER/\t\{$LINE\}\,\nTHREADHOLDER/g" \
                -i stenographer/config
        fi
        let COUNTER=COUNTER+1
    done

    cp stenographer/config /etc/stenographer/config
    sed -e "s/placeholder/$COLLECTION_INTERFACE/g" -i /etc/stenographer/config
    chmod 755 /etc/stenographer
    chown stenographer:stenographer /etc/stenographer/certs
    chmod 750 /etc/stenographer/certs
    /usr/bin/stenokeys.sh stenographer stenographer
    systemctl enable stenographer
    systemctl start stenographer
fi
################################################################################
# INSTALL: FileBeat                                                            #
################################################################################
    cp filebeat/filebeat.yml /etc/filebeat/filebeat.yml
    cp certs/FileBeat/FileBeat.crt /etc/filebeat/FileBeat.crt
    cp certs/ca/ca.crt /etc/filebeat/ca.crt
    cp certs/FileBeat/FileBeat.key /etc/filebeat/FileBeat.key
    systemctl restart filebeat
################################################################################
# CONFIGURE: First User/Admin                                                  #
################################################################################
# Create new admin's home directory
cp -R /etc/skel /home
mv /home/skel /home/$IPA_USERNAME

# Configure IPA client
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
